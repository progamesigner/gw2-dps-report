use std::env;
use std::fs;
use std::io;
use std::time;

fn main() -> io::Result<()> {
    // clean files before 14 days
    let lifetime = 60 * 60 * 24 * 14;

    let entries = fs::read_dir(env::var("FILE_BASE_PATH").unwrap_or("files".to_string()))?;

    for entry in entries {
        if let Ok(entry) = entry {
            if entry.file_type()?.is_dir()
                && entry
                    .path()
                    .file_name()
                    .unwrap()
                    .to_str()
                    .unwrap()
                    .starts_with("evtc-")
            {
                if let Ok(metadata) = fs::metadata(entry.path().to_str().unwrap()) {
                    if time::SystemTime::now()
                        .duration_since(metadata.modified()?)
                        .unwrap()
                        .as_secs()
                        > lifetime
                    {
                        fs::remove_dir_all(entry.path())?;
                        println!("Clean: {:?}", entry.path());
                    }
                }
            }
        }
    }

    Ok(())
}
