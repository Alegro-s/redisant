//! Arena-аллокатор кадра (без malloc в hot loop — цель v1).

/// Простой bump allocator для одного кадра.
pub struct FrameArena {
    buf: Vec<u8>,
    offset: usize,
}

impl FrameArena {
    pub fn with_capacity(bytes: usize) -> Self {
        Self {
            buf: vec![0; bytes],
            offset: 0,
        }
    }

    pub fn reset(&mut self) {
        self.offset = 0;
    }

    pub fn alloc(&mut self, size: usize, align: usize) -> Option<usize> {
        let pad = (align - (self.offset % align)) % align;
        let start = self.offset + pad;
        if start + size > self.buf.len() {
            return None;
        }
        self.offset = start + size;
        Some(start)
    }
}
