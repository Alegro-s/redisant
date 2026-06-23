//! E27 — PCM bus mixer (Core owns audio queue; Flutter plays samples).

use std::collections::HashMap;

#[derive(Clone, Debug)]
pub struct AudioPlayEvent {
    pub path: String,
    pub bus: String,
    pub volume: f32,
}

#[derive(Clone, Debug, Default)]
pub struct AudioMixer {
    pub master_volume: f32,
    pub bus_volumes: HashMap<String, f32>,
    pending: Vec<AudioPlayEvent>,
}

impl AudioMixer {
    pub fn new() -> Self {
        Self {
            master_volume: 1.0,
            bus_volumes: HashMap::new(),
            pending: Vec::new(),
        }
    }

    pub fn set_master(&mut self, v: f32) {
        self.master_volume = v.clamp(0.0, 2.0);
    }

    pub fn set_bus_volume(&mut self, bus: &str, v: f32) {
        self.bus_volumes.insert(bus.to_string(), v.clamp(0.0, 2.0));
    }

    pub fn queue_play(&mut self, path: &str, bus: &str, volume: f32) {
        if path.is_empty() {
            return;
        }
        self.pending.push(AudioPlayEvent {
            path: path.to_string(),
            bus: bus.to_string(),
            volume: volume.clamp(0.0, 2.0),
        });
    }

    pub fn effective_volume(&self, bus: &str, clip_volume: f32) -> f32 {
        let bus_v = self.bus_volumes.get(bus).copied().unwrap_or(1.0);
        (self.master_volume * bus_v * clip_volume).clamp(0.0, 2.0)
    }

    pub fn drain_pending(&mut self) -> Vec<AudioPlayEvent> {
        std::mem::take(&mut self.pending)
    }

    pub fn pending_len(&self) -> usize {
        self.pending.len()
    }
}

/// Legacy placeholder type alias.
pub struct AudioEngine;

impl AudioEngine {
    pub fn new() -> Self {
        Self
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn audio_mixer_bus_and_drain() {
        let mut m = AudioMixer::new();
        m.set_bus_volume("sfx", 0.5);
        m.queue_play("assets/sounds/jump.wav", "sfx", 1.0);
        assert_eq!(m.pending_len(), 1);
        let ev = m.drain_pending();
        assert_eq!(ev.len(), 1);
        assert!((m.effective_volume("sfx", 1.0) - 0.5).abs() < 0.001);
    }
}
