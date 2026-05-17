
pub fn validate_password(password: &str) -> Result<(), String> {
    let min = std::env::var("PASSWORD_MIN_LENGTH")
        .ok()
        .and_then(|s| s.parse::<usize>().ok())
        .filter(|&n| n >= 8)
        .unwrap_or(10);

    if password.len() < min {
        return Err(format!("Пароль слишком короткий: минимум {} символов.", min));
    }
    if password.chars().count() > 256 {
        return Err("Пароль слишком длинный (максимум 256 символов).".into());
    }

    let has_lower = password.chars().any(|c| c.is_ascii_lowercase());
    let has_upper = password.chars().any(|c| c.is_ascii_uppercase());
    let has_digit = password.chars().any(|c| c.is_ascii_digit());
    let has_special = password.chars().any(|c| !c.is_ascii_alphanumeric());

    if !has_lower {
        return Err("В пароле нужна хотя бы одна строчная латинская буква.".into());
    }
    if !has_upper {
        return Err("В пароле нужна хотя бы одна заглавная латинская буква.".into());
    }
    if !has_digit {
        return Err("В пароле нужна хотя бы одна цифра.".into());
    }
    if !has_special {
        return Err(
            "В пароле нужен хотя бы один специальный символ (например !@#$%^&*).".into(),
        );
    }

    Ok(())
}
