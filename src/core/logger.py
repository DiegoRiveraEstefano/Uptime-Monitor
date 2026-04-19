import logging
import sys
from typing import Any, Optional

import structlog
from structlog.types import Processor

from src.core.settings import settings


def configure_logger() -> None:
    """
    Configura structlog para proporcionar logs estructurados y coloreados en consola
    o JSON para producción.
    """
    processors: list[Processor] = [
        structlog.contextvars.merge_contextvars,
        structlog.processors.add_log_level,
        structlog.processors.StackInfoRenderer(),
        structlog.dev.set_exc_info,
        structlog.processors.TimeStamper(fmt="iso"),
    ]

    if settings.logging.json_format:
        processors.append(structlog.processors.JSONRenderer())
    else:
        processors.append(structlog.dev.ConsoleRenderer(colors=True))

    structlog.configure(
        processors=processors,
        logger_factory=structlog.PrintLoggerFactory(),
        wrapper_class=structlog.make_filtering_bound_logger(
            logging.getLevelName(settings.logging.level.upper())
        ),
        cache_logger_on_first_use=True,
    )


def get_logger(name: Optional[str] = None) -> structlog.stdlib.BoundLogger:
    """
    Obtiene una instancia del logger.
    """
    return structlog.stdlib.get_logger(name)


# Inicializar configuración al importar
configure_logger()
logger = get_logger()
