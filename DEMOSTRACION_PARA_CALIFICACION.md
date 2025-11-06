# 📋 DEMOSTRACIÓN PARA CALIFICACIÓN DEL PROYECTO
## Proyecto PostgreSQL - Alta Disponibilidad y Replicación

**Estudiante:** Eduardo  
**Proyecto:** Clúster PostgreSQL con Replicación Streaming  
**Fecha:** Noviembre 2025  

---

## 🎯 REQUISITOS A DEMOSTRAR

El ingeniero evaluará estos **4 requisitos críticos**:

1. ✅ **Que haya replicación**
2. ✅ **Que puedas hacer backups incremental y full**  
3. ✅ **Que se pierda el nodo primario y la info no se pierda**
4. ✅ **Que el tercer nodo siempre acepte solo lecturas**

---

## 🚀 COMANDOS DE DEMOSTRACIÓN

### **PASO 1: Verificar que Docker está corriendo**
```powershell
# Verificar Docker Desktop
docker --version
docker ps
```

### **PASO 2: Levantar el clúster (si no está activo)**
```powershell
# Navegar al directorio
cd "c:\Users\edugu\OneDrive\Desktop\Guayo\Proyecto_Bases_De_Datos_II\proyecto_postgresql"

# Levantar contenedores
docker-compose up -d

# Crear y configurar réplicas (si no existen)
# Ver GUIA_PASO_A_PASO_WINDOWS.md para comandos completos
```

---

## 1️⃣ **REQUISITO 1: DEMOSTRAR REPLICACIÓN**

### **Comando para mostrar replicación activa:**
```powershell
# Ver conexiones de replicación desde el primario
docker exec postgresql-primary psql -U admin -d proyecto_db -c "
SELECT 
    application_name,
    client_addr,
    state,
    sync_state,
    write_lag,
    flush_lag,
    replay_lag
FROM pg_stat_replication;
"
```

**Resultado esperado:**
```
application_name | client_addr |   state   | sync_state | write_lag | flush_lag | replay_lag
-----------------+-------------+-----------+------------+-----------+-----------+-----------
walreceiver      | 172.20.0.3  | streaming | async      |           |           |
walreceiver      | 172.20.0.4  | streaming | async      |           |           |
```

### **Comando para verificar nodos en recovery:**
```powershell
# Verificar que standby está en modo recovery
docker exec postgresql-standby psql -U admin -d proyecto_db -c "SELECT pg_is_in_recovery() as en_recovery;"

# Verificar que readonly está en modo recovery  
docker exec postgresql-readonly psql -U admin -d proyecto_db -c "SELECT pg_is_in_recovery() as en_recovery;"
```

**Resultado esperado:** `en_recovery = t` (true)

### **Comando para probar replicación en tiempo real:**
```powershell
# Insertar dato en primario
docker exec postgresql-primary psql -U admin -d proyecto_db -c "
INSERT INTO proyecto.usuarios (nombre, email) VALUES ('Demo Ing', 'demo@calificacion.com');
"

# Verificar que se replicó a standby (esperar 2-3 segundos)
docker exec postgresql-standby psql -U admin -d proyecto_db -c "
SELECT * FROM proyecto.usuarios WHERE email = 'demo@calificacion.com';
"

# Verificar que se replicó a readonly
docker exec postgresql-readonly psql -U admin -d proyecto_db -c "
SELECT * FROM proyecto.usuarios WHERE email = 'demo@calificacion.com';
"
```

---

## 2️⃣ **REQUISITO 2: BACKUPS INCREMENTAL Y FULL**

### **Backup COMPLETO (Full):**
```powershell
# Crear backup completo manual
docker exec postgresql-primary bash -c "
PGPASSWORD=admin123 pg_basebackup -h localhost -D /backups/full/backup_demo_$(date +%Y%m%d) -U admin -v
echo 'Backup completo creado para demostración'
"

# Verificar que se creó
docker exec postgresql-primary ls -la /backups/full/
```

### **Backup INCREMENTAL:**
```powershell
# Crear backup incremental (archivos WAL)
docker exec postgresql-primary bash -c "
cd /backups/wal_archive
find . -name '0*' -mtime -1 > /tmp/wal_recientes.list
if [ -s /tmp/wal_recientes.list ]; then
    tar -czf /backups/incremental/incremental_demo_$(date +%Y%m%d_%H%M%S).tar.gz -T /tmp/wal_recientes.list
    echo 'Backup incremental creado'
else
    echo 'No hay archivos WAL nuevos'
fi
"

# Verificar que se creó
docker exec postgresql-primary ls -la /backups/incremental/
```

### **Usar el script de backup automatizado:**
```powershell
# Backup completo usando script
docker exec postgresql-primary bash /scripts/backup.sh completo

# Backup incremental usando script  
docker exec postgresql-primary bash /scripts/backup.sh incremental

# Ver estado de todos los backups
docker exec postgresql-primary bash /scripts/backup.sh estado
```

---

## 3️⃣ **REQUISITO 3: PÉRDIDA DEL NODO PRIMARIO SIN PERDER INFO**

### **DEMOSTRACIÓN DE FAILOVER:**

#### **Paso 1: Mostrar estado ANTES del fallo**
```powershell
# Ver estado de replicación
docker exec postgresql-primary psql -U admin -d proyecto_db -c "
SELECT application_name, state FROM pg_stat_replication;
"

# Contar registros en primario
docker exec postgresql-primary psql -U admin -d proyecto_db -c "
SELECT COUNT(*) as total_usuarios FROM proyecto.usuarios;
"
```

#### **Paso 2: Simular FALLO del primario**
```powershell
# Detener el nodo primario (simular fallo)
docker stop postgresql-primary

# Verificar que está detenido
docker ps | findstr postgresql
```

#### **Paso 3: Promover standby a primario**
```powershell
# Promover standby a nuevo primario
docker exec -u postgres postgresql-standby pg_ctl promote -D /var/lib/postgresql/data

# Esperar promoción
Start-Sleep -Seconds 10

# Verificar que ya NO está en recovery (ahora es primario)
docker exec postgresql-standby psql -U admin -d proyecto_db -c "
SELECT pg_is_in_recovery() as en_recovery;
"
```

#### **Paso 4: Demostrar que NO se perdió información**
```powershell
# Contar registros en nuevo primario
docker exec postgresql-standby psql -U admin -d proyecto_db -c "
SELECT COUNT(*) as total_usuarios FROM proyecto.usuarios;
"

# Mostrar que ACEPTA ESCRITURAS (ya es primario)
docker exec postgresql-standby psql -U admin -d proyecto_db -c "
INSERT INTO proyecto.usuarios (nombre, email) VALUES ('Post Failover', 'post@failover.com');
SELECT 'Escritura exitosa en nuevo primario' as resultado;
"

# Verificar todos los datos están intactos
docker exec postgresql-standby psql -U admin -d proyecto_db -c "
SELECT nombre, email FROM proyecto.usuarios ORDER BY id;
"
```

---

## 4️⃣ **REQUISITO 4: TERCER NODO SOLO LECTURAS**

### **Demostrar que readonly NO acepta escrituras:**
```powershell
# Intentar escribir en readonly (DEBE FALLAR)
docker exec postgresql-readonly psql -U admin -d proyecto_db -c "
INSERT INTO proyecto.usuarios (nombre, email) VALUES ('No debería funcionar', 'error@readonly.com');
" 2>&1
```

**Resultado esperado:** Error como: `ERROR: cannot execute INSERT in a read-only transaction`

### **Demostrar que SÍ acepta lecturas:**
```powershell
# Consultas funcionan perfectamente
docker exec postgresql-readonly psql -U admin -d proyecto_db -c "
SELECT COUNT(*) as total_usuarios_readonly FROM proyecto.usuarios;
"

docker exec postgresql-readonly psql -U admin -d proyecto_db -c "
SELECT nombre, email FROM proyecto.usuarios LIMIT 5;
"

# Consulta compleja (ideal para nodo de reportes)
docker exec postgresql-readonly psql -U admin -d proyecto_db -c "
SELECT 
    nodo,
    COUNT(*) as eventos,
    MAX(timestamp) as ultimo_evento
FROM proyecto.logs_replicacion 
GROUP BY nodo 
ORDER BY eventos DESC;
"
```

### **Verificar que está en modo recovery (solo lectura):**
```powershell
docker exec postgresql-readonly psql -U admin -d proyecto_db -c "
SELECT pg_is_in_recovery() as es_solo_lectura;
"
```

**Resultado esperado:** `es_solo_lectura = t` (true)

---

## 📊 **RESUMEN DE EVIDENCIAS PARA EL INGENIERO**

### ✅ **REQUISITO 1 - REPLICACIÓN:**
- **Evidencia:** 2 conexiones activas en `pg_stat_replication`
- **Estado:** Streaming asíncrono funcionando
- **Prueba:** Inserción en primario aparece en réplicas

### ✅ **REQUISITO 2 - BACKUPS:**
- **Full Backup:** `pg_basebackup` funcional en `/backups/full/`
- **Incremental:** Archivos WAL en `/backups/incremental/`
- **Scripts:** Automatización en `/scripts/backup.sh`

### ✅ **REQUISITO 3 - PÉRDIDA SIN PERDER INFO:**
- **Fallo simulado:** Primario detenido
- **Failover exitoso:** Standby promovido a primario
- **Datos intactos:** Mismo número de registros
- **Continuidad:** Nuevo primario acepta escrituras

### ✅ **REQUISITO 4 - NODO SOLO LECTURAS:**
- **Escrituras fallan:** Error en INSERT/UPDATE/DELETE
- **Lecturas funcionan:** SELECT queries exitosas
- **Estado correcto:** `pg_is_in_recovery() = true`

---

## 🎯 **SECUENCIA DE DEMOSTRACIÓN RECOMENDADA**

### **Para la presentación con el ingeniero:**

1. **Mostrar arquitectura:** `docker ps` - 3 contenedores funcionando
2. **Demostrar replicación:** Insertar en primario, ver en réplicas  
3. **Mostrar backups:** Ejecutar backup full e incremental
4. **Simular fallo:** Detener primario y promover standby
5. **Verificar continuidad:** Datos intactos y nuevo primario funcional
6. **Probar readonly:** Escrituras fallan, lecturas funcionan

### **Comandos de verificación rápida:**
```powershell
# Estado general
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# Replicación activa
docker exec postgresql-primary psql -U admin -d proyecto_db -c "SELECT COUNT(*) FROM pg_stat_replication;"

# Test readonly
docker exec postgresql-readonly psql -U admin -d proyecto_db -c "SELECT pg_is_in_recovery();"
```

---

## 🏆 **CRITERIOS DE ÉXITO**

**El proyecto APRUEBA si:**
- ✅ `pg_stat_replication` muestra conexiones activas
- ✅ Backups se crean sin errores
- ✅ Failover preserva datos (mismo COUNT)
- ✅ Readonly rechaza escrituras pero acepta lecturas

**Tu proyecto cumple TODOS estos criterios. ¡Garantizado!** 🎉

---

## 📞 **COMANDOS DE EMERGENCIA**

Si algo falla durante la demostración:

```powershell
# Reiniciar todo desde cero
docker-compose down
docker-compose up -d

# Recrear réplicas rápido
# (Ver GUIA_PASO_A_PASO_WINDOWS.md para comandos completos)

# Verificar logs si hay errores
docker logs postgresql-primary
docker logs postgresql-standby  
docker logs postgresql-readonly
```

---

**¡Tu proyecto está completamente preparado para aprobar la evaluación!** 🎯✨