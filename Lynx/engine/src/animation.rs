use std::sync::{Arc, Mutex};

use serde::{Deserialize, Serialize};

use crate::{Entity, TexRect};
use crate::runtime::SignalEvent;

#[derive(Clone, Debug, Serialize, Deserialize, Default)]
pub struct AnimKeyEvent {
    pub frame: usize,
    #[serde(rename = "type")]
    pub kind: String,
    #[serde(default)]
    pub name: Option<String>,
    #[serde(default)]
    pub code: Option<String>,
}

#[derive(Clone, Debug, Serialize, Deserialize, Default)]
pub struct SpriteAnim {
    pub frames: Vec<TexRect>,
    pub fps: f32,
    #[serde(default)]
    pub events: Vec<AnimKeyEvent>,
}

fn current_frame_index(e: &Entity) -> Option<usize> {
    let anim = e.sprite.animation.as_ref()?;
    if anim.frames.is_empty() {
        return None;
    }
    let fps = anim.fps.max(0.001);
    let looping = e.animator.as_ref().map(|a| a.looping).unwrap_or(true);
    let t = if let Some(a) = &e.animator {
        a.time
    } else {
        e.playback_time
    };
    let frame_index = (t * fps).floor() as usize;
    let idx = if looping {
        frame_index % anim.frames.len()
    } else {
        frame_index.min(anim.frames.len() - 1)
    };
    Some(idx)
}

/// Выставляет `sprite.uv_rect` по `sprite.animation` и времени аниматора / локальным часам.
pub fn apply_sprite_animation_uv(entities: &mut [Entity], dt: f32) {
    for e in entities {
        let Some(anim) = e.sprite.animation.as_ref() else {
            continue;
        };
        if anim.frames.is_empty() {
            continue;
        }
        let idx = current_frame_index(e).unwrap_or(0);
        e.sprite.uv_rect = Some(anim.frames[idx]);
        if e.animator.is_none() {
            e.playback_time += dt;
        }
    }
}

/// События на кадрах клипа → очередь сигналов (волна 9b).
pub fn dispatch_anim_key_events(
    entities: &mut [Entity],
    signal_queue: &Arc<Mutex<Vec<SignalEvent>>>,
) {
    for e in entities {
        let Some(idx) = current_frame_index(e) else {
            e.last_anim_frame = None;
            continue;
        };
        let prev = e.last_anim_frame;
        e.last_anim_frame = Some(idx);
        if prev == Some(idx) {
            continue;
        }
        let Some(anim) = e.sprite.animation.as_ref() else {
            continue;
        };
        for ev in &anim.events {
            if ev.frame != idx {
                continue;
            }
            match ev.kind.as_str() {
                "signal" => {
                    if let Some(name) = &ev.name {
                        if !name.is_empty() {
                            signal_queue.lock().unwrap().push(SignalEvent {
                                name: name.clone(),
                                source_id: e.id,
                            });
                        }
                    }
                }
                "lua" => {
                    if let Some(code) = &ev.code {
                        if !code.is_empty() {
                            signal_queue.lock().unwrap().push(SignalEvent {
                                name: format!("anim_lua:{code}"),
                                source_id: e.id,
                            });
                        }
                    }
                }
                _ => {}
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::{Entity, SpriteData, Vec2};

    fn entity_with_anim(fps: f32, frames: Vec<TexRect>) -> Entity {
        let mut e = Entity::new(0, "hero", Vec2::ZERO, crate::Color::WHITE);
        e.sprite = SpriteData {
            animation: Some(SpriteAnim {
                frames,
                fps,
                events: vec![AnimKeyEvent {
                    frame: 1,
                    kind: "signal".into(),
                    name: Some("footstep".into()),
                    code: None,
                }],
            }),
            ..Default::default()
        };
        e.animator = Some(crate::EntityAnimator {
            clip_id: "run".into(),
            time: 0.15,
            speed: 1.0,
            looping: true,
        });
        e
    }

    #[test]
    fn uv_advances_with_animator_time() {
        let frames = vec![
            TexRect { x: 0.0, y: 0.0, w: 32.0, h: 32.0 },
            TexRect { x: 32.0, y: 0.0, w: 32.0, h: 32.0 },
        ];
        let mut e = entity_with_anim(10.0, frames);
        e.animator.as_mut().unwrap().time = 0.15;
        apply_sprite_animation_uv(std::slice::from_mut(&mut e), 0.0);
        let uv = e.sprite.uv_rect.unwrap();
        assert_eq!(uv.x, 32.0);
    }

    #[test]
    fn key_event_on_frame_change() {
        let frames = vec![
            TexRect { x: 0.0, y: 0.0, w: 16.0, h: 16.0 },
            TexRect { x: 16.0, y: 0.0, w: 16.0, h: 16.0 },
        ];
        let mut e = entity_with_anim(10.0, frames);
        e.animator.as_mut().unwrap().time = 0.0;
        let q = Arc::new(Mutex::new(Vec::new()));
        dispatch_anim_key_events(std::slice::from_mut(&mut e), &q);
        assert!(q.lock().unwrap().is_empty());
        e.animator.as_mut().unwrap().time = 0.15;
        dispatch_anim_key_events(std::slice::from_mut(&mut e), &q);
        assert_eq!(q.lock().unwrap().len(), 1);
        assert_eq!(q.lock().unwrap()[0].name, "footstep");
    }
}
