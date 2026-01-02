//! SQLite database for sound indexing and fingerprint storage

use crate::{AudioPaletteError, Result, SoundRecord};
use crate::fingerprint::AudioFingerprint;
use rusqlite::{Connection, params};
use std::path::Path;

/// Database for sound palette management
pub struct PaletteDatabase {
    conn: Connection,
}

impl PaletteDatabase {
    /// Open or create database at path
    pub fn open<P: AsRef<Path>>(path: P) -> Result<Self> {
        let conn = Connection::open(path)?;
        let db = PaletteDatabase { conn };
        db.create_schema()?;
        Ok(db)
    }

    /// Create in-memory database (for testing)
    pub fn open_in_memory() -> Result<Self> {
        let conn = Connection::open_in_memory()?;
        let db = PaletteDatabase { conn };
        db.create_schema()?;
        Ok(db)
    }

    fn create_schema(&self) -> Result<()> {
        self.conn.execute_batch(
            r#"
            CREATE TABLE IF NOT EXISTS sounds (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                filepath TEXT NOT NULL UNIQUE,
                filename TEXT NOT NULL,
                duration REAL,
                sample_rate INTEGER,
                channels INTEGER,
                format TEXT,
                date_added TEXT DEFAULT CURRENT_TIMESTAMP
            );

            CREATE TABLE IF NOT EXISTS fingerprints (
                sound_id INTEGER PRIMARY KEY REFERENCES sounds(id) ON DELETE CASCADE,
                fingerprint_json TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS categories (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL,
                parent_id INTEGER REFERENCES categories(id)
            );

            CREATE TABLE IF NOT EXISTS sound_categories (
                sound_id INTEGER REFERENCES sounds(id) ON DELETE CASCADE,
                category_id INTEGER REFERENCES categories(id) ON DELETE CASCADE,
                PRIMARY KEY (sound_id, category_id)
            );

            CREATE INDEX IF NOT EXISTS idx_sounds_filepath ON sounds(filepath);
            CREATE INDEX IF NOT EXISTS idx_sounds_filename ON sounds(filename);
            "#
        )?;
        Ok(())
    }

    /// Add a sound to the database
    pub fn add_sound(&self, filepath: &str, filename: &str, duration: f64,
                     sample_rate: u32, channels: u16, format: &str) -> Result<i64> {
        self.conn.execute(
            "INSERT OR IGNORE INTO sounds (filepath, filename, duration, sample_rate, channels, format)
             VALUES (?1, ?2, ?3, ?4, ?5, ?6)",
            params![filepath, filename, duration, sample_rate, channels, format],
        )?;

        let id = self.conn.query_row(
            "SELECT id FROM sounds WHERE filepath = ?1",
            params![filepath],
            |row| row.get(0),
        )?;

        Ok(id)
    }

    /// Store fingerprint for a sound
    pub fn store_fingerprint(&self, sound_id: i64, fingerprint: &AudioFingerprint) -> Result<()> {
        let json = serde_json::to_string(fingerprint)
            .map_err(|e| AudioPaletteError::FingerprintError(e.to_string()))?;

        self.conn.execute(
            "INSERT OR REPLACE INTO fingerprints (sound_id, fingerprint_json) VALUES (?1, ?2)",
            params![sound_id, json],
        )?;

        Ok(())
    }

    /// Get fingerprint for a sound
    pub fn get_fingerprint(&self, sound_id: i64) -> Result<Option<AudioFingerprint>> {
        let result: rusqlite::Result<String> = self.conn.query_row(
            "SELECT fingerprint_json FROM fingerprints WHERE sound_id = ?1",
            params![sound_id],
            |row| row.get(0),
        );

        match result {
            Ok(json) => {
                let fp: AudioFingerprint = serde_json::from_str(&json)
                    .map_err(|e| AudioPaletteError::FingerprintError(e.to_string()))?;
                Ok(Some(fp))
            }
            Err(rusqlite::Error::QueryReturnedNoRows) => Ok(None),
            Err(e) => Err(e.into()),
        }
    }

    /// Get all fingerprints for similarity search
    pub fn get_all_fingerprints(&self) -> Result<Vec<(i64, AudioFingerprint)>> {
        let mut stmt = self.conn.prepare(
            "SELECT sound_id, fingerprint_json FROM fingerprints"
        )?;

        let results: Vec<(i64, AudioFingerprint)> = stmt
            .query_map([], |row| {
                let id: i64 = row.get(0)?;
                let json: String = row.get(1)?;
                Ok((id, json))
            })?
            .filter_map(|r| r.ok())
            .filter_map(|(id, json)| {
                serde_json::from_str(&json).ok().map(|fp| (id, fp))
            })
            .collect();

        Ok(results)
    }

    /// Get sound by ID
    pub fn get_sound(&self, id: i64) -> Result<Option<SoundRecord>> {
        let result = self.conn.query_row(
            "SELECT id, filepath, filename, duration, sample_rate, channels, format, date_added
             FROM sounds WHERE id = ?1",
            params![id],
            |row| {
                Ok(SoundRecord {
                    id: row.get(0)?,
                    filepath: row.get(1)?,
                    filename: row.get(2)?,
                    duration: row.get(3)?,
                    sample_rate: row.get(4)?,
                    channels: row.get(5)?,
                    format: row.get(6)?,
                    date_added: row.get(7)?,
                })
            },
        );

        match result {
            Ok(sound) => Ok(Some(sound)),
            Err(rusqlite::Error::QueryReturnedNoRows) => Ok(None),
            Err(e) => Err(e.into()),
        }
    }

    /// Get all sounds
    pub fn get_all_sounds(&self) -> Result<Vec<SoundRecord>> {
        let mut stmt = self.conn.prepare(
            "SELECT id, filepath, filename, duration, sample_rate, channels, format, date_added
             FROM sounds ORDER BY date_added DESC"
        )?;

        let sounds = stmt
            .query_map([], |row| {
                Ok(SoundRecord {
                    id: row.get(0)?,
                    filepath: row.get(1)?,
                    filename: row.get(2)?,
                    duration: row.get(3)?,
                    sample_rate: row.get(4)?,
                    channels: row.get(5)?,
                    format: row.get(6)?,
                    date_added: row.get(7)?,
                })
            })?
            .filter_map(|r| r.ok())
            .collect();

        Ok(sounds)
    }

    /// Search sounds by filename
    pub fn search(&self, query: &str) -> Result<Vec<SoundRecord>> {
        let pattern = format!("%{}%", query);
        let mut stmt = self.conn.prepare(
            "SELECT id, filepath, filename, duration, sample_rate, channels, format, date_added
             FROM sounds WHERE filename LIKE ?1 ORDER BY filename"
        )?;

        let sounds = stmt
            .query_map(params![pattern], |row| {
                Ok(SoundRecord {
                    id: row.get(0)?,
                    filepath: row.get(1)?,
                    filename: row.get(2)?,
                    duration: row.get(3)?,
                    sample_rate: row.get(4)?,
                    channels: row.get(5)?,
                    format: row.get(6)?,
                    date_added: row.get(7)?,
                })
            })?
            .filter_map(|r| r.ok())
            .collect();

        Ok(sounds)
    }

    /// Remove sound from database
    pub fn remove_sound(&self, id: i64) -> Result<()> {
        self.conn.execute("DELETE FROM fingerprints WHERE sound_id = ?1", params![id])?;
        self.conn.execute("DELETE FROM sounds WHERE id = ?1", params![id])?;
        Ok(())
    }

    /// Get sound count
    pub fn count(&self) -> Result<i64> {
        let count: i64 = self.conn.query_row("SELECT COUNT(*) FROM sounds", [], |row| row.get(0))?;
        Ok(count)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_database_operations() {
        let db = PaletteDatabase::open_in_memory().unwrap();

        // Add sound
        let id = db.add_sound("/test/sound.wav", "sound.wav", 1.5, 44100, 2, "wav").unwrap();
        assert!(id > 0);

        // Get sound
        let sound = db.get_sound(id).unwrap().unwrap();
        assert_eq!(sound.filename, "sound.wav");

        // Search
        let results = db.search("sound").unwrap();
        assert_eq!(results.len(), 1);

        // Count
        assert_eq!(db.count().unwrap(), 1);

        // Remove
        db.remove_sound(id).unwrap();
        assert_eq!(db.count().unwrap(), 0);
    }
}
