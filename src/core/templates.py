from starlette.templating import Jinja2Templates
from src.core.settings import BASE_DIR

# Directorio de plantillas
TEMPLATES_DIR = BASE_DIR / "templates"

# Inicializar motor de plantillas
templates = Jinja2Templates(directory=str(TEMPLATES_DIR))

# Podríamos añadir filtros o funciones globales aquí
# templates.env.globals["now"] = datetime.datetime.now
