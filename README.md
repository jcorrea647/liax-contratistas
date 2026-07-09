# LIAX Contratistas Seguros

Plataforma de gestión de seguridad de contratistas para Codelco División Ventanas.
Producto SEPARADO del LIAX educativo — reusa patrones, NO archivos ni infraestructura.

## Puesta en marcha

### 1. Infraestructura (crear vacía, en el navegador)
- **GitHub:** repo nuevo `liax-contratistas` (privado).
- **Supabase:** proyecto NUEVO (no el educativo). Anota Project URL y anon key.
- **Vercel:** importa el repo; agrega las env vars de abajo.

### 2. Variables de entorno (Vercel → Settings → Environment Variables)
Copia de `.env.example`:
- `SUPABASE_URL`, `SUPABASE_ANON_KEY` — del Supabase nuevo.
- `GEMINI_API_KEY` — de Google AI Studio.

### 3. Base de datos (Supabase → SQL Editor, en orden)
1. `sql/00_modelo_base_contratistas.sql` — tablas base + helpers de aislamiento.
2. `sql/01_agentes_chat_contratistas.sql` — agentes, sesiones, documentos, config.
3. `sql/esquema_rags_contratistas.sql` — tabla `rags`.

### 4. Cargar el RESSO
```
npm install
SUPABASE_URL=... SUPABASE_SERVICE_KEY=... npm run cargar-resso
```

## Aislamiento (crítico)
El aislamiento por `contratista_id` vive en la RLS de Supabase, no en el JS.
El mandante (Codelco) ve todo; cada contratista ve solo lo suyo.
