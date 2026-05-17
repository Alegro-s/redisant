
pub fn strip_sql_comments(input: &str) -> String {
    let mut out = String::with_capacity(input.len());
    let mut chars = input.chars().peekable();
    let mut in_line_comment = false;
    let mut block_depth = 0i32;
    while let Some(c) = chars.next() {
        if in_line_comment {
            if c == '\n' {
                in_line_comment = false;
                out.push('\n');
            }
            continue;
        }
        if block_depth > 0 {
            if c == '/' && chars.peek() == Some(&'*') {
                chars.next();
                block_depth += 1;
                continue;
            }
            if c == '*' && chars.peek() == Some(&'/') {
                chars.next();
                block_depth -= 1;
                continue;
            }
            continue;
        }
        if c == '-' && chars.peek() == Some(&'-') {
            chars.next();
            in_line_comment = true;
            continue;
        }
        if c == '/' && chars.peek() == Some(&'*') {
            chars.next();
            block_depth = 1;
            continue;
        }
        out.push(c);
    }
    out
}

fn normalized_start(query: &str) -> String {
    strip_sql_comments(query)
        .trim()
        .trim_end_matches(';')
        .trim()
        .to_lowercase()
}

pub fn validate_agent_readonly(q: &str) -> Result<(), &'static str> {
    let q = q.trim();
    if q.is_empty() {
        return Err("Empty query");
    }
    let core = q.trim_end_matches(';').trim();
    if core.contains(';') {
        return Err("Multiple SQL statements are not allowed");
    }
    let start = normalized_start(q);
    if start.is_empty() {
        return Err("Empty query after comments");
    }
    if !start.starts_with("select") && !start.starts_with("with") {
        return Err("Only SELECT or WITH ... SELECT is allowed");
    }
    Ok(())
}
