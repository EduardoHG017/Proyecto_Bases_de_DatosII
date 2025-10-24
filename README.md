# Proyecto PostgreSQL - Replicación en Streaming con Docker

Este proyecto implementa un clúster PostgreSQL con 3 nodos usando replicación en streaming, failover manual y estrategia completa de respaldos, todo containerizado con Docker.

## 🏗️ Arquitectura del Sistema

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   NODO PRIMARIO │────▶│  NODO STANDBY   │     │  NODO READONLY  │
│   (Puerto 5432) │     │   (Puerto 5433) │     │   (Puerto 5434) │
│                 │     │                 │     │                 │
│ ✓ Lectura/Escri │     │ ✓ Solo Lectura  │     │ ✓ Solo Lectura  │
│ ✓ Replicación   │     │ ✓ Failover Ready│     │ ✓ Reportes      │
│ ✓ Respaldos     │     │ ✓ Hot Standby   │     │ ✓ Consultas     │
└─────────────────┘     └─────────────────┘     └─────────────────┘
         │                        ▲                        ▲
         │                        │                        │
         └────────── Replicación Streaming ─────────────────┘
```

## 📋 Características Principales

### ✅ Replicación en Streaming
- **WAL Level**: `replica` configurado en todos los nodos
- **Hot Standby**: Habilitado para consultas en nodos secundarios
- **Replicación Asíncrona**: Streaming en tiempo real
- **Usuario Replicador**: `replicator` con permisos específicos

### ✅ Failover Manual
- Script automatizado para promover standby
- Simulación de caída del nodo primario
- Verificación automática del estado post-failover
- Restauración de configuración original

### ✅ Estrategia de Respaldos
- **Backup Completo**: Semanal (domingos 2:00 AM)
- **Backup Incremental**: Diario (1:00 AM, lunes-sábado)
- **Archivado WAL**: Continuo para point-in-time recovery
- **Retención**: 7 días automática
- **Verificación de Integridad**: Semanal

### ✅ Monitoreo Avanzado
- Estado de replicación en tiempo real
- Métricas de lag entre nodos
- Estadísticas de base de datos
- Logs centralizados
- Alertas automáticas

## 🚀 Inicio Rápido

### 1. Levantar el Clúster

```bash
# Navegar al directorio del proyecto
cd proyecto_postgresql

# Levantar todos los contenedores
docker-compose up -d

# Ejecutar configuración automática
./scripts/setup.sh
```

### 2. Verificar Estado

```bash
# Monitorear el estado de replicación
./scripts/monitor.sh estado

# Monitoreo continuo en tiempo real
./scripts/monitor.sh continuo
```

### 3. Conectar a los Nodos

```bash
# Conectar al nodo primario (lectura/escritura)
psql -h localhost -p 5432 -U admin -d proyecto_db

# Conectar al nodo standby (solo lectura)
psql -h localhost -p 5433 -U admin -d proyecto_db

# Conectar al nodo readonly (solo lectura)
psql -h localhost -p 5434 -U admin -d proyecto_db
```

## 📁 Estructura del Proyecto

```
proyecto_postgresql/
├── docker-compose.yml          # Configuración principal de Docker
├── README.md                   # Esta documentación
│
├── primary/                    # Configuración nodo primario
│   ├── postgresql.conf         # Configuración PostgreSQL
│   ├── pg_hba.conf            # Configuración de autenticación
│   └── init-primary.sh        # Script de inicialización
│
├── standby/                    # Configuración nodo standby
│   ├── postgresql.conf         # Configuración PostgreSQL
│   ├── pg_hba.conf            # Configuración de autenticación
│   └── init-standby.sh        # Script de inicialización
│
├── readonly/                   # Configuración nodo readonly
│   ├── postgresql.conf         # Configuración PostgreSQL
│   ├── pg_hba.conf            # Configuración de autenticación
│   └── init-readonly.sh       # Script de inicialización
│
├── scripts/                    # Scripts de gestión
│   ├── setup.sh               # Configuración automática
│   ├── monitor.sh             # Monitoreo del clúster
│   ├── failover.sh            # Gestión de failover
│   ├── backup.sh              # Sistema de respaldos
│   └── setup_cron.sh          # Configuración de respaldos automáticos
│
└── backups/                    # Directorio de respaldos
    ├── full/                  # Backups completos
    ├── incremental/           # Backups incrementales
    └── wal_archive/           # Archivos WAL
```

## ⚙️ Configuración Detallada

### Nodos del Clúster

| Nodo | Puerto | Función | Descripción |
|------|--------|---------|-------------|
| **Primary** | 5432 | Lectura/Escritura | Nodo principal que acepta todas las operaciones |
| **Standby** | 5433 | Solo Lectura + Failover | Replica sincronizada lista para promoción |
| **Readonly** | 5434 | Solo Lectura | Optimizado para consultas y reportes |

### Credenciales

| Usuario | Contraseña | Función |
|---------|------------|---------|
| `admin` | `admin123` | Usuario administrador principal |
| `replicator` | `replica123` | Usuario específico para replicación |

### Variables de Entorno

```yaml
POSTGRES_DB: proyecto_db
POSTGRES_USER: admin
POSTGRES_PASSWORD: admin123
POSTGRES_REPLICATION_USER: replicator
POSTGRES_REPLICATION_PASSWORD: replica123
```

## 🔧 Scripts de Gestión

### 1. Setup Automático
```bash
./scripts/setup.sh              # Configuración completa
./scripts/setup.sh test          # Solo ejecutar pruebas
./scripts/setup.sh info          # Mostrar información de conexión
./scripts/setup.sh clean         # Limpiar instalación
```

### 2. Monitoreo
```bash
./scripts/monitor.sh estado      # Estado actual del clúster
./scripts/monitor.sh continuo    # Monitoreo en tiempo real
./scripts/monitor.sh estadisticas # Estadísticas de BD
./scripts/monitor.sh conectividad # Prueba de conectividad
./scripts/monitor.sh reporte     # Generar reporte completo
```

### 3. Failover Manual
```bash
./scripts/failover.sh           # Menú interactivo de failover
```

Opciones del script de failover:
1. **Mostrar estado actual** - Ver estado de replicación
2. **Simular caída + Failover** - Detener primario y promover standby
3. **Solo promover standby** - Promoción sin detener primario (split-brain)
4. **Restaurar configuración** - Volver al estado original
5. **Salir**

### 4. Sistema de Respaldos
```bash
./scripts/backup.sh completo     # Backup completo manual
./scripts/backup.sh incremental  # Backup incremental manual
./scripts/backup.sh estado       # Estado de respaldos
./scripts/backup.sh verificar    # Verificar integridad
./scripts/backup.sh limpiar      # Limpiar respaldos antiguos
```

### 5. Respaldos Automáticos
```bash
./scripts/setup_cron.sh         # Configurar respaldos automáticos
```

**Programación automática (crontab):**
- **Backup completo**: Domingos 2:00 AM
- **Backup incremental**: Lunes-Sábado 1:00 AM
- **Verificación**: Miércoles 3:00 AM
- **Limpieza**: Diario 4:00 AM
- **Monitoreo**: Cada 15 minutos

## 🗃️ Estrategia de Respaldos

### Tipos de Respaldo

1. **Backup Completo (pg_basebackup)**
   - Frecuencia: Semanal (domingos)
   - Incluye: Todos los datos y configuraciones
   - Formato: TAR comprimido (gzip nivel 6)
   - Ubicación: `/backups/full/`

2. **Backup Incremental (WAL)**
   - Frecuencia: Diario
   - Incluye: Archivos WAL de las últimas 24 horas
   - Formato: TAR comprimido
   - Ubicación: `/backups/incremental/`

3. **Archivado WAL Continuo**
   - Frecuencia: Continuo
   - Comando: `cp %p /backups/wal_archive/%f`
   - Propósito: Point-in-time recovery

### Política de Retención
- **Respaldos**: 7 días
- **Archivos WAL**: 3 días
- **Limpieza**: Automática diaria a las 4:00 AM

## 🧪 Pruebas y Verificación

### Pruebas Automáticas

El script `setup.sh` ejecuta las siguientes pruebas:

1. **Conectividad** - Verificar conexión a los 3 nodos
2. **Replicación** - Confirmar estado de streaming
3. **Funcionalidad** - Insertar datos y verificar replicación
4. **Integridad** - Contar registros en todos los nodos

### Pruebas Manuales

```sql
-- 1. Verificar estado de replicación (desde primario)
SELECT * FROM pg_stat_replication;

-- 2. Verificar si un nodo está en recovery
SELECT pg_is_in_recovery();

-- 3. Ver último LSN replicado
SELECT pg_last_wal_replay_lsn();

-- 4. Verificar datos de ejemplo
SELECT * FROM proyecto.usuarios;
SELECT * FROM proyecto.logs_replicacion;

-- 5. Probar inserción en primario
INSERT INTO proyecto.usuarios (nombre, email) 
VALUES ('Test User', 'test@example.com');

-- 6. Verificar replicación en standby/readonly
SELECT COUNT(*) FROM proyecto.usuarios;
```

## 🔍 Troubleshooting

### Problemas Comunes

#### 1. Nodo no inicia
```bash
# Ver logs del contenedor
docker logs postgresql-primary
docker logs postgresql-standby
docker logs postgresql-readonly

# Verificar permisos
docker exec postgresql-primary ls -la /var/lib/postgresql/data/
```

#### 2. Replicación no funciona
```bash
# Verificar conectividad de red
docker exec postgresql-standby ping postgresql-primary

# Verificar usuario replicador
docker exec postgresql-primary psql -U admin -d proyecto_db -c "SELECT * FROM pg_roles WHERE rolname='replicator';"

# Verificar configuración pg_hba.conf
docker exec postgresql-primary cat /etc/postgresql/pg_hba.conf | grep replication
```

#### 3. Failover no responde
```bash
# Verificar estado del standby
docker exec postgresql-standby pg_controldata /var/lib/postgresql/data/

# Forzar promoción manual
docker exec postgresql-standby pg_ctl promote -D /var/lib/postgresql/data/
```

#### 4. Respaldos fallan
```bash
# Verificar permisos del directorio
docker exec postgresql-primary ls -la /backups/

# Verificar espacio en disco
docker exec postgresql-primary df -h

# Ver logs de backup
docker exec postgresql-primary cat /backups/backup.log
```

### Comandos de Diagnóstico

```bash
# Estado general del clúster
docker-compose ps
docker stats

# Logs en tiempo real
docker-compose logs -f

# Conectividad entre contenedores
docker network inspect proyecto_postgresql_postgresql-network

# Uso de recursos
docker exec postgresql-primary top
docker exec postgresql-primary free -h
docker exec postgresql-primary df -h
```

## 📊 Monitoreo y Métricas

### Métricas Importantes

1. **Lag de Replicación**
   ```sql
   SELECT 
       application_name,
       write_lag,
       flush_lag,
       replay_lag
   FROM pg_stat_replication;
   ```

2. **Estado de Archivado WAL**
   ```sql
   SELECT 
       archived_count,
       failed_count,
       last_archived_wal,
       last_archived_time
   FROM pg_stat_archiver;
   ```

3. **Estadísticas de Conexiones**
   ```sql
   SELECT 
       count(*) as total_connections,
       state
   FROM pg_stat_activity
   GROUP BY state;
   ```

### Alertas Recomendadas

- **Lag de replicación > 10 segundos**
- **Espacio en disco < 10%**
- **Errores en archivado WAL**
- **Conexiones > 80% del máximo**
- **Backup falló**

## 🔒 Consideraciones de Seguridad

### Para Producción

1. **Cambiar contraseñas por defecto**
2. **Restringir reglas en pg_hba.conf**
3. **Usar certificados SSL/TLS**
4. **Configurar firewall**
5. **Habilitar logging detallado**
6. **Monitoreo de seguridad**

### Configuración SSL (Opcional)

```bash
# Generar certificados
openssl req -new -x509 -days 365 -nodes -text -out server.crt -keyout server.key

# Configurar en postgresql.conf
ssl = on
ssl_cert_file = 'server.crt'
ssl_key_file = 'server.key'
```

## 📚 Referencias y Recursos

- [PostgreSQL Streaming Replication](https://www.postgresql.org/docs/15/warm-standby.html)
- [pg_basebackup Documentation](https://www.postgresql.org/docs/15/app-pgbasebackup.html)
- [Docker Compose Reference](https://docs.docker.com/compose/)
- [PostgreSQL High Availability](https://www.postgresql.org/docs/15/high-availability.html)

## 👥 Soporte

Para reportar problemas o solicitar mejoras:

1. Verificar logs con `docker-compose logs`
2. Ejecutar diagnósticos con `./scripts/monitor.sh`
3. Revisar esta documentación
4. Contactar al equipo de desarrollo

---

**Proyecto de Base de Datos II**  
*Universidad - 2025*

*Este proyecto implementa un clúster PostgreSQL completo con replicación, failover y respaldos automatizados usando Docker y herramientas estándar de PostgreSQL.*