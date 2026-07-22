# 📘 Manual de Despliegue, Ventas y Arquitectura CRM Multicanal

Este documento contiene la **guía técnica y comercial completa** de la plataforma CRM Multicanal personalizada. Utiliza esta guía para recordar todo el funcionamiento, presentar demostraciones a clientes e instalar el sistema en producción.

---

## 🛠️ 1. Resumen de Personalizaciones y Arquitectura

### 🎨 Diseño y UI (Cumplimiento de Reglas Globales)
* **CSS Puro:** Estilos modulares sin Tailwind ad-hoc en componentes personalizados. Uso de CSS variables, Flexbox y Grid Layout.
* **Tipografías y Títulos Adaptativos:** Uso de `clamp()` para adaptar automáticamente los títulos (`H1`-`H6`) a cualquier pantalla.
* **Rendimiento:** Optimización con `content-visibility: auto`, `aspect-ratio` y `lazy loading` en imágenes.
* **Traducción al Español:** Todos los módulos, incluyendo la configuración de *Web Support*, *Kanban*, *Campañas* e *Indicadores*, están 100% traducidos al español natural.

### 💼 Módulos Principales
1. **Embudo de Ventas (Tablero Kanban):**
   * Gestiona el flujo comercial en 5 etapas reactivas con colores únicos:
     * 🟡 **Prospecto** (Ámbar / Amarillo)
     * 🔵 **Contacto Realizado** (Azul)
     * 🟣 **Demostración Programada** (Morado)
     * 🟠 **Propuesta Enviada** (Naranja)
     * 🟢 **Negociación / Venta** (Verde)
   * Compatible 100% con **Modo Claro** y **Modo Oscuro** (Dark Mode).
2. **Indicador de Etapa en Conversaciones:**
   * Cada tarjeta de cliente en la lista principal de conversaciones muestra una **etiqueta/badge de color reactivo** con la fase actual del lead en el CRM (ej: `🟡 Prospecto`, `🟢 Negociación`), permitiendo a los vendedores priorizar de un vistazo.
3. **Logos de Marca Oficiales a Todo Color (`use-brand-icon`):**
   * 💬 **WhatsApp Ventas:** Logo verde oficial de WhatsApp.
   * 📸 **Instagram DM:** Logo oficial en degradado rosa/morado de Instagram.
   * ⚡ **Facebook Messenger:** Logo oficial azul de Messenger.
   * ✈️ **Telegram Soporte:** Logo oficial azul de Telegram.
   * 🌐 **Web Support:** Icono oficial del chat web widget.
4. **Agente IA (Captain AI / Assistants):**
   * Desbloqueado al 100% (sin barreras ni paywalls Enterprise). Permite entrenar IAs con documentos, preguntas frecuentes y flujos 24/7.
5. **Almacenamiento Multimedia y Retención Automática:**
   * Configurable desde *SuperAdmin → Storage & Retention* para conectar **Cloudflare R2** o **Hetzner Storage Box** (S3).
   * **Job nocturno de purga (`Internal::MediaRetentionJob`):** Elimina adjuntos antiguos (fotos, audios, PDFs de más de $N$ meses) conservando el historial de texto 100% intacto.
6. **Respaldos Mensuales Automáticos a Google Drive (`bin/backup_to_gdrive.sh`):**
   * Script automatizado que genera dumps comprimidos de PostgreSQL (`.sql.gz`) y los sube vía `rclone` directamente al Google Drive del cliente con retención de 12 meses.

---

## 🚀 2. Guía de Comandos para Demostraciones

El proyecto cuenta con comandos Rake automatizados para preparar o limpiar la plataforma en segundos:

### 📥 Poblar la Demo con Datos Masivos (Para Vender)
Ejecuta el siguiente comando en la consola o terminal del proyecto:
```bash
bundle exec rails demo:poblar
```
*(Si usas Docker / WSL: `wsl -d Ubuntu docker compose -f /root/chatwoot/docker-compose.yaml exec -T rails bundle exec rails demo:poblar`)*

**¿Qué genera este comando?**
* 👥 **Agentes de Prueba:** Crea a *Laura Ramírez* (Vendedora) y *Pedro Castro* (Vendedor).
* 📥 **18 Conversaciones Multicanal:** Distribuidas en WhatsApp, Instagram, Facebook Messenger, Telegram y Web Support.
* 📊 **Distribución de Pestañas:** 5 en *Mías*, 5 en *Sin asignar* (para probar reclamos en vivo) y 18 en *Todos*.
* 🏷️ **9 Tratos Kanban:** Asignados a los contactos con valores y etapas en el embudo de ventas.
* 📢 **2 Campañas Activas:** Campaña emergente de bienvenida web y campaña masiva por WhatsApp.

### 🧹 Limpiar el CRM por Completo (Para Entregar a un Cliente)
Cuando vayas a entregarle la plataforma a un cliente final recién comprado, ejecuta:
```bash
bundle exec rails demo:limpiar
```
*(Si usas Docker / WSL: `wsl -d Ubuntu docker compose -f /root/chatwoot/docker-compose.yaml exec -T rails bundle exec rails demo:limpiar`)*

**¿Qué hace este comando?**
* Elimina todas las conversaciones, tratos, contactos, campañas y bandejas de prueba, dejando la instalación **100% limpia y como nueva** lista para producción.

---

## ☁️ 3. Guía de Despliegue en Producción (10 a 15 Minutos)

### 📋 Requisitos Previos para el Cliente
1. **Servidor VPS Recomendado:** **Hetzner Cloud - Plan CX23** (2 vCPU, 4 GB RAM, 40 GB NVMe) por **~$6.50 USD/mes**.
2. **Sistema Operativo:** Ubuntu 22.04 LTS o Ubuntu 24.04 LTS.
3. **Dominio o Subdominio:** Ejemplo: `crm.elnegociodelcliente.com`.
4. **Cuenta en Cloudflare (Gratis):** Para gestionar el DNS y certificado HTTPS/SSL automático.

### 🛠️ Pasos de Instalación en el Servidor

1. **Conectarse al servidor VPS por SSH:**
   ```bash
   ssh root@<IP_DEL_SERVIDOR>
   ```

2. **Instalar Docker y Docker Compose (1 comando):**
   ```bash
   curl -fsSL https://get.docker.com | sh
   ```

3. **Clonar tu Repositorio de GitHub:**
   ```bash
   git clone https://github.com/rioscee/chatwoot.git /root/chatwoot
   cd /root/chatwoot
   ```

4. **Arrancar la Aplicación con Docker Compose:**
   ```bash
   docker compose up -d
   ```

5. **Preparar la Base de Datos Inicial:**
   ```bash
   docker compose exec rails bundle exec rails db:chatwoot_prepare
   ```

6. **Configurar el Dominio en Cloudflare:**
   * Crear un registro `A` apuntando `crm.elnegociodelcliente.com` a la `<IP_DEL_SERVIDOR>`.
   * Activar el proxy de Cloudflare (icono de nube naranja) para SSL/HTTPS automático.

7. **Configurar Almacenamiento Externo (Cloudflare R2):**
   * Crear bucket en Cloudflare R2 e ingresar llaves API en *SuperAdmin → Storage & Retention* (`/super_admin/app_config?config=storage`).

8. **Activar Backups Automáticos Mensuales a Google Drive:**
   * Instalar `rclone` (`curl https://rclone.org/install.sh | bash`), vincular la cuenta del cliente (`rclone config` -> `gdrive_chatwoot`) y agregar la tarea en `crontab -e`:
     `0 2 1 * * /root/chatwoot/bin/backup_to_gdrive.sh >> /var/log/chatwoot_backup.log 2>&1`

---

## 💡 4. Argumentos Comerciales y Preguntas Frecuentes para Clientes

### ❓ ¿Hay riesgo de baneo en WhatsApp?
**No, 0% riesgo.** La plataforma utiliza la **WhatsApp Cloud API Oficial de Meta (Graph API)**. No utiliza librerías de scraping ni emuladores web no oficiales. Cada mensaje está 100% autorizado por Meta.

### ❓ ¿Existe Coexistencia con la App de WhatsApp Business?
**Sí.** Meta permite mantener la app móvil de WhatsApp Business conectada mientras el equipo responde desde el CRM a través de la API oficial.

### ❓ ¿Se pueden conectar varios números de WhatsApp?
**Sí, ilimitados.** Puedes crear una bandeja para cada número (ej: *WhatsApp Ventas*, *WhatsApp Soporte*, *WhatsApp Sucursal 2*) y asignar qué agentes atienden cada línea.

### ❓ ¿Cómo se conecta al sitio web del cliente?
Mediante un **código Script JavaScript de 1 línea** generado automáticamente en *Ajustes → Bandejas de Entrada → Web Support*. Es compatible con WordPress, Shopify, Wix, React, HTML puro, etc.

### 💰 Modelo de Negocio SaaS Recomendado
* **Costo de Servidor VPS (Hetzner CX23):** ~$6.50 USD / mes.
* **Precio de Venta al Cliente:** $35.00 - $50.00 USD / mes (incluyendo CRM + servidor + soporte).
* **Ganancia Limpia:** **+$28.50 a $43.50 USD al mes por cliente** (Ingreso recurrente pasivo).

---
*Documento generado y sincronizado en el repositorio oficial.*
