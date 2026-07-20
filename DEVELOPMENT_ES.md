# Guía de Desarrollo y Arquitectura de Chatwoot (Optimizado para IA)

Esta guía detalla la arquitectura, el flujo de desarrollo y las pautas técnicas del proyecto Chatwoot, diseñada para que tanto desarrolladores humanos como agentes de inteligencia artificial puedan comprender y trabajar en este código de inmediato.

---

## 🛠️ Stack Tecnológico

El proyecto está estructurado como una aplicación monolítica moderna con desacoplamiento en el frontend:

*   **Backend (Ruby on Rails 7.x):** Proporciona las API REST y WebSockets (ActionCable), maneja la lógica de negocio, las conexiones a canales externos y las integraciones.
*   **Frontend (Vue.js 3 + Vite):** Construido como una SPA (Single Page Application) montada sobre la estructura de Rails en `app/javascript/`.
*   **Base de Datos (PostgreSQL 16):** Almacenamiento principal. Requiere la extensión `pgvector` para el funcionamiento del agente de soporte con IA (Captain).
*   **Colas y Background Jobs (Redis + Sidekiq):** Gestión de trabajos asíncronos como el envío de correos, sincronización de mensajes de Facebook/WhatsApp e integraciones.
*   **Entorno de Correo Local (Mailhog):** Captura todos los correos electrónicos de salida en desarrollo para su inspección local.

---

## 📂 Estructura y Arquitectura del Directorio

*   **[app/](file:///e:/Proyectos%20Saas/chatwoot/app):** Directorio raíz de la aplicación Rails.
    *   **[controllers/](file:///e:/Proyectos%20Saas/chatwoot/app/controllers):** Controladores de la API (generalmente heredan de `Api::V1::BaseController`).
    *   **[models/](file:///e:/Proyectos%20Saas/chatwoot/app/models):** Modelos de ActiveRecord con sus validaciones, asociaciones y llamadas recurrentes.
    *   **[services/](file:///e:/Proyectos%20Saas/chatwoot/app/services):** Objetos de servicio que encapsulan acciones de negocio de un único propósito (ej. crear mensajes, configurar bandejas de entrada).
    *   **[javascript/](file:///e:/Proyectos%20Saas/chatwoot/app/javascript):** Código frontend en Vue 3. Estructurado en componentes, vistas, stores y mixins.
*   **[enterprise/](file:///e:/Proyectos%20Saas/chatwoot/enterprise):** Directorio que sobreescribe o extiende las funcionalidades de la edición Open Source (OSS).
    *   *Regla Crítica para IA:* Al modificar lógica del core, siempre se debe validar si existe un archivo homólogo en `enterprise/`. Si existe, se debe extender la lógica utilizando `prepend_mod_with` o hooks de inclusión para evitar inconsistencias entre versiones.
*   **[config/](file:///e:/Proyectos%20Saas/chatwoot/config):** Configuraciones globales, inicializadores (`config/initializers/`) y archivos de traducción (`config/locales/`).
*   **[db/](file:///e:/Proyectos%20Saas/chatwoot/db):** Migraciones de base de datos, esquemas (`schema.rb`) y semillas de datos (`seeds.rb`).

---

## ⚡ Ejecución Local con Docker Desktop

Debido a que levantar PostgreSQL (con `pgvector`) y Redis nativamente en Windows es sumamente complejo, la vía estándar es utilizar **Docker Desktop**.

### 1. Iniciar Docker Desktop
Asegúrate de que Docker Desktop esté abierto y corriendo. Puedes verificarlo desde la terminal con:
```powershell
docker compose version
docker ps
```

### 2. Levantar los Contenedores
Inicia todos los servicios del stack en segundo plano utilizando el archivo [docker-compose.yaml](file:///e:/Proyectos%20Saas/chatwoot/docker-compose.yaml):
```powershell
docker compose up -d --build
```
Esto iniciará los servicios de Rails, Vite (frontend), Postgres, Redis, Sidekiq y Mailhog.

### 3. Crear y Preparar la Base de Datos
La primera vez que levantes el proyecto, debes ejecutar las migraciones e insertar los datos iniciales de prueba (seeding):
```powershell
docker compose exec rails bundle exec rails db:prepare db:seed
```

### 4. Acceso Local
*   **Aplicación Web (Chatwoot):** [http://localhost:3000](http://localhost:3000)
*   **Buzón de Correos Local (Mailhog):** [http://localhost:8025](http://localhost:8025)

---

## 🇪🇸 Configuración de Idioma (Español)

Para configurar el entorno de Chatwoot por defecto en español:
1.  El archivo [.env](file:///e:/Proyectos%20Saas/chatwoot/.env) ya está configurado con `DEFAULT_LOCALE=es`.
2.  Las traducciones del backend se gestionan a través de [config/locales/es.yml](file:///e:/Proyectos%20Saas/chatwoot/config/locales/es.yml).
3.  Las traducciones del frontend se leen desde los ficheros JSON correspondientes en la carpeta de i18n del cliente.
4.  Cualquier nueva cuenta o registro por defecto se inicializará con interfaz en español. Los usuarios también pueden cambiar su idioma personal desde su perfil.

---

## 🤖 Pautas Especiales para Agentes de IA (Custom Rules)

Al desarrollar o modificar código en este repositorio, la IA debe adherirse estrictamente a las siguientes reglas definidas por el usuario:

### 1. Reglas de Estilos y CSS
*   **NUNCA USAR TAILWIND CSS** para código nuevo, a pesar de que el repositorio de Chatwoot lo traiga de forma nativa.
*   **CSS Puro:** Todo diseño nuevo debe realizarse con CSS Vanilla puro y estructurado de forma modular (separando el CSS para que se cargue únicamente bajo demanda en los módulos específicos).
*   **Layouts:** Priorizar siempre el uso de **Flexbox** y **CSS Grid** para la maquetación.
*   **Mediaqueries:** Minimizar su uso al máximo.
*   **Títulos Responsivos:** Utilizar siempre la función `clamp()` en los títulos (`H1` a `H6`) para garantizar su adaptabilidad automática a cualquier tamaño de pantalla.
*   **Párrafos:** Configurar el tamaño de la fuente de los párrafos en `20px` siempre que sea posible.
*   **Optimización de Renderizado:**
    *   Usar `content-visibility: auto` en secciones, contenedores o divs pesados para diferir la renderización del contenido fuera de pantalla.
    *   Usar `loading="lazy"` para todas las imágenes.
    *   Definir la propiedad `aspect-ratio` en elementos multimedia para evitar saltos de maquetación (CLS - Cumulative Layout Shift).
    *   Incluir obligatoriamente el atributo `alt` descriptivo en las etiquetas `img` para garantizar accesibilidad.

### 2. Lógica del Backend (Ruby on Rails)
*   Mantener definiciones de clases y módulos de manera compacta (ej. `class Api::V1::BaseController < ApplicationController`).
*   Seguir las reglas estandarizadas de RuboCop definidas en el proyecto.
*   Preferir siempre el uso de `bundle exec` para lanzar comandos de Rails o pruebas.

### 3. Lógica del Frontend (Vue 3)
*   Utilizar la **Composition API** de Vue 3 con el bloque `<script setup>` al inicio del archivo.
*   Seguir la guía de estilo de ESLint configurada en el repositorio.
