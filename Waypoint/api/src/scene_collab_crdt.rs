
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};
use std::collections::HashMap;
use uuid::Uuid;

#[derive(Clone, Copy, Debug, Serialize, Deserialize, PartialEq, Eq, PartialOrd, Ord)]
pub struct Hlc {
    #[serde(rename = "wall_ms")]
    pub wall_ms: u64,
    pub logical: u64,
    pub site: Uuid,
}

#[derive(Debug, Clone, Deserialize)]
pub struct CrdtOpIn {
    pub path: String,
    pub value: Value,
    pub hlc: Hlc,
}

pub struct CrdtRoom {
    pub content: Value,
    pub path_hlc: HashMap<String, Hlc>,
    pub revision: i64,
    pub text_ot: HashMap<String, TextOtState>,
}

#[derive(Debug, Clone)]
pub struct TextOtState {
    pub text: String,
    pub rev: u64,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(tag = "kind", rename_all = "lowercase")]
pub enum OtOpIn {
    Ins { pos: usize, text: String },
    Del { pos: usize, len: usize },
}

fn pointer_set(root: &mut Value, pointer: &str, val: Value) -> bool {
    let p = pointer.trim();
    if p.is_empty() || p == "/" {
        *root = val;
        return true;
    }
    let segs: Vec<&str> = p.trim_start_matches('/').split('/').filter(|s| !s.is_empty()).collect();
    if segs.is_empty() {
        *root = val;
        return true;
    }
    let last = segs.len() - 1;
    let mut cur = root;
    for (i, seg) in segs.iter().enumerate() {
        let is_last = i == last;
        if is_last {
            if let Ok(idx) = seg.parse::<usize>() {
                match cur {
                    Value::Array(arr) => {
                        if idx < arr.len() {
                            arr[idx] = val;
                        } else if idx == arr.len() {
                            arr.push(val);
                        } else {
                            return false;
                        }
                    }
                    _ => return false,
                }
            } else if let Value::Object(map) = cur {
                map.insert((*seg).to_string(), val);
            } else {
                return false;
            }
            return true;
        }
        if let Ok(idx) = seg.parse::<usize>() {
            match cur {
                Value::Array(arr) => {
                    if idx >= arr.len() {
                        arr.push(json!({}));
                    }
                    cur = &mut arr[idx];
                }
                _ => return false,
            }
        } else if let Value::Object(map) = cur {
            cur = map.entry((*seg).to_string()).or_insert(json!({}));
        } else {
            return false;
        }
    }
    false
}

impl CrdtRoom {
    pub fn apply_lww_ops(&mut self, ops: &[CrdtOpIn]) {
        for op in ops {
            let prev = self.path_hlc.get(&op.path).copied();
            if prev.map_or(true, |p| op.hlc > p) {
                let _ = pointer_set(&mut self.content, &op.path, op.value.clone());
                self.path_hlc.insert(op.path.clone(), op.hlc);
            }
        }
        self.revision = self.revision.saturating_add(1);
    }

    pub fn replace_if_newer(&mut self, content: Value, revision: i64) -> bool {
        if revision > self.revision {
            self.content = content;
            self.path_hlc.clear();
            self.revision = revision;
            return true;
        }
        false
    }

    pub fn apply_text_ot(&mut self, target: &str, base_rev: u64, op: &OtOpIn) -> Result<u64, String> {
        let st = self
            .text_ot
            .entry(target.to_string())
            .or_insert_with(|| TextOtState {
                text: String::new(),
                rev: 0,
            });
        if base_rev != st.rev {
            return Err(format!("rev mismatch: client {} server {}", base_rev, st.rev));
        }
        match op {
            OtOpIn::Ins { pos, text } => {
                if *pos > st.text.len() {
                    return Err("ins position OOB".into());
                }
                st.text.insert_str(*pos, text);
            }
            OtOpIn::Del { pos, len } => {
                if *pos > st.text.len() || *pos + *len > st.text.len() {
                    return Err("del range OOB".into());
                }
                st.text.drain(*pos..*pos + *len);
            }
        }
        st.rev = st.rev.saturating_add(1);
        Ok(st.rev)
    }

    pub fn get_text_state(&self, target: &str) -> Option<(String, u64)> {
        self.text_ot
            .get(target)
            .map(|s| (s.text.clone(), s.rev))
    }

    pub fn seed_text_target(&mut self, target: &str, text: String) {
        self.text_ot.insert(
            target.to_string(),
            TextOtState { text, rev: 1 },
        );
    }
}

impl Default for CrdtRoom {
    fn default() -> Self {
        Self {
            content: json!({}),
            path_hlc: HashMap::new(),
            revision: 0,
            text_ot: HashMap::new(),
        }
    }
}
