
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

pub(crate) fn normalized_start(query: &str) -> String {
    strip_sql_comments(query)
        .trim()
        .trim_end_matches(';')
        .trim()
        .to_lowercase()
}

const DANGEROUS_PREFIXES: &[&str] = &[
    "insert ",
    "update ",
    "delete ",
    "drop ",
    "truncate ",
    "alter ",
    "create ",
    "grant ",
    "revoke ",
    "copy ",
    "call ",
    "merge ",
    "replace ", // MySQL-стиль; в PG редко, но блокируем
];

pub fn validate_admin_query(
    query: &str,
    read_only: bool,
    allow_raw: bool,
    allow_write: bool,
) -> Result<(), &'static str> {
    if !allow_raw {
        return Err("Raw SQL is disabled (set ADMIN_ALLOW_RAW_SQL=1 in non-production or explicitly enable)");
    }

    let q = query.trim();
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

    if read_only {
        if !start.starts_with("select") && !start.starts_with("with") {
            return Err("read_only mode: only SELECT or WITH ... SELECT is allowed");
        }
        return Ok(());
    }

    if !allow_write {
        for p in DANGEROUS_PREFIXES {
            if start.starts_with(p) {
                return Err("Write SQL disabled (set ADMIN_ALLOW_SQL_WRITE=1)");
            }
        }
        if start.starts_with("select")
            || start.starts_with("with")
            || start.starts_with("explain")
            || start.starts_with("show")
        {
            return Ok(());
        }
        return Err("Non-SELECT statements require ADMIN_ALLOW_SQL_WRITE=1");
    }

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn rejects_double_statement() {
        let r = validate_admin_query("SELECT 1; DROP TABLE users;", true, true, false);
        assert!(r.is_err());
    }

    #[test]
    fn read_only_allows_select() {
        assert!(validate_admin_query("SELECT 1", true, true, false).is_ok());
    }

    #[test]
    fn read_only_rejects_update() {
        assert!(validate_admin_query("UPDATE users SET role='x'", true, true, false).is_err());
    }

    #[test]
    fn disabled_raw() {
        assert!(validate_admin_query("SELECT 1", true, false, false).is_err());
    }

    #[test]
    fn write_needs_flag() {
        assert!(validate_admin_query("DELETE FROM users", false, true, false).is_err());
    }

    #[test]
    fn strip_comments() {
        let s = strip_sql_comments("-- hi\nSELECT 1");
        assert_eq!(s.trim(), "SELECT 1");
    }
}
