#!/bin/bash

echo "🚀 Configurando Cloud Build Trigger..."
echo "======================================"

# Variables
PROJECT_ID="trusty-hangar-474303-t7"
TRIGGER_NAME="web-app-trigger"
GITHUB_OWNER="Kgtoledoc"
GITHUB_REPO="gcp-cloudbuild"
REGION="us-central1"
SERVICE_NAME="web-app"
REPO_NAME="gcp-technical-test"
SECURITY_POLICY_NAME="web-app-security-policy"
BLOCKED_IP="186.169.36.153"

echo "📋 Configuración:"
echo "  - Proyecto: $PROJECT_ID"
echo "  - Repositorio: $GITHUB_OWNER/$GITHUB_REPO"
echo "  - Región: $REGION"
echo "  - Servicio: $SERVICE_NAME"
echo ""

# Verificar si gcloud está instalado
if ! command -v gcloud &> /dev/null; then
    echo "❌ gcloud CLI no está instalado"
    echo "   Instala desde: https://cloud.google.com/sdk/docs/install"
    exit 1
fi

# Configurar proyecto
echo "🔧 Configurando proyecto..."
gcloud config set project $PROJECT_ID

# Crear el trigger
echo "🔨 Creando trigger de Cloud Build..."
gcloud builds triggers create github \
    --repo-name=$GITHUB_REPO \
    --repo-owner=$GITHUB_OWNER \
    --branch-pattern="^main$" \
    --build-config="cloudbuild.yaml" \
    --name=$TRIGGER_NAME \
    --description="Trigger for web application CI/CD pipeline" \
    --substitutions="_REGION=$REGION,_REPO_NAME=$REPO_NAME,_SERVICE_NAME=$SERVICE_NAME,_SECURITY_POLICY_NAME=$SECURITY_POLICY_NAME,_BLOCKED_IP=$BLOCKED_IP" \
    --service-account="projects/$PROJECT_ID/serviceAccounts/cloud-build-sa@$PROJECT_ID.iam.gserviceaccount.com"

if [ $? -eq 0 ]; then
    echo "✅ Trigger creado exitosamente!"
    echo ""
    echo "🔗 Ver trigger en consola:"
    echo "   https://console.cloud.google.com/cloud-build/triggers?project=$PROJECT_ID"
    echo ""
    echo "📝 Para probar el trigger:"
    echo "   1. Haz push a la rama main de tu repositorio"
    echo "   2. Ve a Cloud Build para ver el progreso"
    echo "   3. La aplicación se actualizará automáticamente"
else
    echo "❌ Error al crear el trigger"
    echo "   Verifica que el repositorio esté conectado"
    exit 1
fi
