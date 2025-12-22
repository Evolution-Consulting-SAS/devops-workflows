# Automatización de Despliegues con GitHub Actions  
## Sistema ECPAY2

Este repositorio contiene la implementación del flujo de **automatización de despliegues** para los microservicios del sistema **ECPAY2**, utilizando **GitHub Actions** y **workflows reutilizables**.

El objetivo principal de esta solución es:
- Centralizar la lógica de despliegue
- Evitar duplicación de workflows en cada microservicio
- Facilitar el mantenimiento del flujo de CI/CD
- Permitir que nuevos microservicios se integren fácilmente al proceso de despliegue automático
- Garantizar trazabilidad y consistencia entre ramas y entornos

Esta documentación describe **cómo funciona el flujo**, **qué componentes intervienen** y **qué requisitos debe cumplir cada microservicio** para integrarse correctamente.

---

## 1. Relación entre ramas y entornos

El sistema ECPAY2 sigue un flujo basado en **Gitflow**, donde cada rama principal del repositorio está asociada a un entorno de despliegue específico:

- **development**  
  Entorno local de la empresa (servidor en oficina).  
  Este entorno **no está automatizado**, ya que requiere autenticación manual mediante Tailscale y SSH.

- **staging**  
  Entorno de pruebas desplegado en una instancia **EC2 de AWS**.  
  Este entorno **sí está automatizado** mediante GitHub Actions.

- **release**  
  Entorno productivo desplegado en una instancia **EC2 de AWS**, accedida a través de un **bastión**.  
  Este entorno **sí está automatizado** mediante GitHub Actions.

Cada vez que se realiza un `push` o se acepta un Pull Request en alguna de estas ramas, se puede disparar automáticamente el flujo de despliegue correspondiente.

---

## 2. Enfoque general de la automatización

En lugar de definir un workflow completo de despliegue en cada microservicio, se decidió implementar un enfoque centralizado:

- Cada microservicio contiene un workflow **mínimo**
- Toda la lógica de despliegue se encuentra en este repositorio (`devops-workflows`)
- Los microservicios **invocan plantillas reutilizables**
- La selección del entorno se realiza automáticamente según la rama que activó el workflow

De esta forma:
- Cambios en la lógica de despliegue se hacen en un solo lugar
- No es necesario modificar cada repositorio cuando el flujo cambia
- Se reduce el riesgo de configuraciones inconsistentes entre microservicios

---

## 3. Arquitectura de workflows

El flujo de despliegue está compuesto por **tres niveles de workflows**.

### 3.1 Workflow del microservicio

Cada microservicio debe contener un workflow en:

```
.github/workflows/ECPAY2-ms-deploy.yml
```

Este workflow:
- Se ejecuta ante cualquier `push` al repositorio
- No contiene lógica de despliegue
- Únicamente invoca una plantilla reutilizable ubicada en `devops-workflows`

Este archivo puede ser **idéntico en todos los microservicios**.

**Ejemplo:**

```yaml
name: ECPAY2 Deploy Microservice

on:
  push:

jobs:
  deploy:
    uses: Evolution-Consulting-SAS/devops-workflows/.github/workflows/ECPAY2-select-environment-deploy-template.yml@release
    secrets: inherit
```

**Nota:**  
Si se desea un control más granular (por ejemplo, solo ciertas ramas), esto puede ajustarse aquí.  
Sin embargo, la recomendación es mantener el control centralizado en el selector de entorno.

---

### 3.2 Selector de entorno

```
{Sistema}-select-environment-deploy-template.yml
```

Este workflow se encuentra en el repositorio `devops-workflows` y es el encargado de:

- Determinar desde qué rama se activó el workflow
- Decidir qué entorno debe desplegarse
- Invocar la plantilla de despliegue correspondiente

Para el sistema ECPAY2, este archivo es:

```
ECPAY2-select-environment-deploy-template.yml
```

Su responsabilidad principal es centralizar la relación rama → entorno, evitando que cada microservicio tenga que definir esta lógica.

**Ejemplo conceptual del flujo:**

```
rd_ecpay_reports_ms_v2
→ push a la rama staging
→ se ejecuta ECPAY2-ms-deploy.yml
→ se llama a ECPAY2-select-environment-deploy-template.yml
→ se detecta la rama staging
→ se ejecuta ECPAY2-deploy-staging-template.yml
```

---

### 3.3 Plantillas de despliegue por entorno

```
{Sistema}-deploy-{entorno}-template.yml
```

Para cada entorno existe una plantilla específica que contiene los pasos técnicos del despliegue.

**Ejemplos en ECPAY2:**

- ECPAY2-deploy-staging-template.yml
- ECPAY2-deploy-release-template.yml

Estas plantillas se encargan de:

- Conectarse al servidor correspondiente (EC2 de pruebas o productivo)
- Navegar a la carpeta donde se encuentra el microservicio
- Actualizar el código desde GitHub (git pull)
- Ejecutar el script `tool_deploy.sh`
- Finalizar el despliegue

---

## 4. Convención crítica de nombres

⚠️ **IMPORTANTE**

Para que el flujo funcione correctamente en ECPAY2, es obligatorio que:

- El nombre del repositorio  
  **Coincida exactamente con**  
  el nombre de la carpeta donde se encuentra el microservicio en el servidor de despliegue

Esto es necesario porque las plantillas de despliegue utilizan la variable:

```
github.event.repository.name
```

para localizar automáticamente la carpeta del microservicio en el servidor.

**Si los nombres no coinciden, el despliegue fallará.**

---

## 5. Archivos requeridos en cada microservicio

Cada microservicio que quiera integrarse al flujo de automatización debe contener exactamente dos archivos clave.

### 5.1 Workflow del microservicio

```
.github/workflows/ECPAY2-ms-deploy.yml
```

Este archivo:

- Dispara el flujo de despliegue
- Invoca el selector de entorno
- Puede reutilizarse sin cambios en todos los microservicios

### 5.2 Script tool_deploy.sh

Este script debe ubicarse en la raíz del repositorio del microservicio.

Su responsabilidad es:

- Compilar o preparar el microservicio
- Levantar el contenedor correspondiente
- Ejecutar únicamente la lógica específica del microservicio

Este script:

- Se ejecuta desde la carpeta raíz del microservicio
- Asume que el `docker-compose.yml` del sistema se encuentra un nivel arriba
- Puede variar según la tecnología del microservicio (Java, Node, frontend, etc.)

**Ejemplo: rd_ecpay_reports_ms_v2**

```bash
#!/bin/bash
# Script de deploy para rd_ecpay_reports_ms_v2
# Asume que se ejecuta desde la raíz del microservicio
# y que el docker-compose se encuentra en el directorio padre

sudo mvn clean package -DskipTests

cd ..

sudo docker-compose down reports_v2_service
sudo docker-compose build reports_v2_service
sudo docker-compose up -d reports_v2_service
```

**Requisitos importantes:**
* El nombre del servicio debe coincidir con el definido en el `docker-compose.yml`

---

## 6. Ejemplo completo del flujo de despliegue

1. Se acepta un Pull Request en la rama `staging`
2. GitHub dispara el workflow `ECPAY2-ms-deploy.yml`
3. Este workflow llama a `ECPAY2-select-environment-deploy-template.yml`
4. El selector detecta que la rama es `staging`
5. Se invoca `ECPAY2-deploy-staging-template.yml`
6. El workflow:
    - Se conecta al EC2 de pruebas
    - Navega a la carpeta del microservicio usando el nombre del repositorio
    - Ejecuta `git pull origin staging`
    - Ejecuta el script `tool_deploy.sh`
    - El contenedor actualizado queda desplegado
    - El proceso de despliegue finaliza exitosamente
