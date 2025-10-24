# ===================================================================
# GUÍA DE INICIO RÁPIDO PARA WINDOWS
# ===================================================================

## 🚀 INICIO RÁPIDO (3 pasos)

### 1. Abrir PowerShell como Administrador
```powershell
# Navegar al directorio del proyecto
cd "C:\Users\edugu\OneDrive\Desktop\Proyecto_Bases_De_Datos_II\proyecto_postgresql"
```

### 2. Ejecutar el menú interactivo
```powershell
.\comandos.ps1 menu
```

### 3. Seleccionar opción 1 para levantar el clúster
```
Seleccione una opción: 1
```

## ⚡ COMANDOS DIRECTOS

### Gestión del Clúster
```powershell
# Levantar clúster completo
.\comandos.ps1 iniciar

# Ver estado actual
.\comandos.ps1 estado

# Monitoreo en tiempo real
.\comandos.ps1 monitor

# Detener clúster
.\comandos.ps1 detener
```

### Respaldos
```powershell
# Backup completo
.\comandos.ps1 backup-completo

# Backup incremental
.\comandos.ps1 backup-incremental
```

### Failover y Diagnóstico
```powershell
# Ejecutar failover manual
.\comandos.ps1 failover

# Ver logs
.\comandos.ps1 logs

# Conectar con psql
.\comandos.ps1 conectar
```

### Mantenimiento
```powershell
# Limpiar y reiniciar todo
.\comandos.ps1 limpiar
```

## 🔗 CONEXIONES DIRECTAS CON PSQL

```powershell
# Conectar al nodo primario (lectura/escritura)
psql -h localhost -p 5432 -U admin -d proyecto_db

# Conectar al nodo standby (solo lectura)
psql -h localhost -p 5433 -U admin -d proyecto_db

# Conectar al nodo readonly (solo lectura)
psql -h localhost -p 5434 -U admin -d proyecto_db
```

**Credenciales:**
- Usuario: `admin`
- Contraseña: `admin123`
- Base de datos: `proyecto_db`

## 🧪 COMANDOS DE PRUEBA

### Verificar replicación
```sql
-- En el nodo primario
INSERT INTO proyecto.usuarios (nombre, email) 
VALUES ('Test Usuario', 'test@prueba.com');

-- En nodos standby/readonly
SELECT * FROM proyecto.usuarios WHERE email = 'test@prueba.com';
```

### Ver estado de replicación
```sql
-- Solo en el nodo primario
SELECT * FROM pg_stat_replication;
```

### Verificar modo de cada nodo
```sql
-- En cualquier nodo
SELECT 
    CASE 
        WHEN pg_is_in_recovery() THEN 'STANDBY/READONLY' 
        ELSE 'PRIMARIO' 
    END as modo_nodo;
```

## 🔧 COMANDOS DOCKER DIRECTOS

```powershell
# Ver estado de contenedores
docker-compose ps

# Ver logs en tiempo real
docker-compose logs -f

# Reiniciar un contenedor específico
docker-compose restart postgresql-primary

# Ejecutar comando en contenedor
docker exec -it postgresql-primary bash

# Ver uso de recursos
docker stats
```

## 📊 MONITOREO CON DOCKER

```powershell
# Ver logs del primario
docker logs postgresql-primary --tail 50

# Ver logs del standby
docker logs postgresql-standby --tail 50

# Ver logs del readonly
docker logs postgresql-readonly --tail 50

# Seguir logs en tiempo real
docker logs -f postgresql-primary
```

## 🛠️ TROUBLESHOOTING WINDOWS

### Si psql no está disponible:
1. Instalar PostgreSQL cliente en Windows
2. O usar desde dentro del contenedor:
```powershell
docker exec -it postgresql-primary psql -U admin -d proyecto_db
```

### Si hay errores de permisos:
```powershell
# Ejecutar PowerShell como Administrador
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Si Docker no responde:
```powershell
# Reiniciar Docker Desktop
# O desde línea de comandos:
docker system prune -f
docker-compose down
docker-compose up -d
```

## 📁 ESTRUCTURA DE ARCHIVOS WINDOWS

```
proyecto_postgresql\
├── docker-compose.yml          # Configuración principal
├── comandos.ps1                # Scripts de PowerShell para Windows
├── INICIO_RAPIDO_WINDOWS.md    # Esta guía
├── README.md                   # Documentación completa
│
├── primary\                    # Configuración nodo primario
├── standby\                    # Configuración nodo standby  
├── readonly\                   # Configuración nodo readonly
├── scripts\                    # Scripts bash (para contenedores)
└── backups\                    # Directorio de respaldos
```

## ⚠️ NOTAS IMPORTANTES PARA WINDOWS

1. **PowerShell**: Los scripts están optimizados para PowerShell 5.1+
2. **Docker Desktop**: Debe estar ejecutándose antes de iniciar
3. **WSL2**: Recomendado para mejor rendimiento
4. **Antivirus**: Agregar excepciones para Docker y el proyecto
5. **Firewall**: Permitir conexiones en puertos 5432, 5433, 5434

## 🔥 SECUENCIA TÍPICA DE TRABAJO

```powershell
# 1. Iniciar proyecto
.\comandos.ps1 iniciar

# 2. Verificar que todo está bien
.\comandos.ps1 estado

# 3. Probar conexión y hacer consultas
.\comandos.ps1 conectar

# 4. Crear backup de seguridad
.\comandos.ps1 backup-completo

# 5. Probar failover (opcional)
.\comandos.ps1 failover

# 6. Al terminar el trabajo
.\comandos.ps1 detener
```

¡Listo para usar! 🎉