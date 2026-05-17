"""Проверка опциональных зависимостей для обучения."""


def training_imports_ok() -> tuple[bool, list[str]]:
    missing: list[str] = []
    try:
        import torch  # noqa: F401
    except ImportError:
        missing.append("torch")
    try:
        import transformers  # noqa: F401
    except ImportError:
        missing.append("transformers")
    try:
        import datasets  # noqa: F401
    except ImportError:
        missing.append("datasets")
    try:
        import peft  # noqa: F401
    except ImportError:
        missing.append("peft")
    try:
        import trl  # noqa: F401
    except ImportError:
        missing.append("trl")
    try:
        import accelerate  # noqa: F401
    except ImportError:
        missing.append("accelerate")
    return (len(missing) == 0, missing)
