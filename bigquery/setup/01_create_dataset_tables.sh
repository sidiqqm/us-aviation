set -euo pipefail

# Configuration
PROJECT_ID="us-aviation-analytics"       # ← Ganti dengan project ID Anda
DATASET="raw"
LOCATION="US"
SCHEMA_DIR="$(dirname "$0")/../schema"

echo " Project  : $PROJECT_ID"
echo " Dataset  : $DATASET"
echo " Location : $LOCATION"
echo "========================================"

# Step 1: Set active project
gcloud config set project "$PROJECT_ID"
echo ""
echo "[1/4] Active project set to: $PROJECT_ID"

# Step 2: Create dataset
echo ""
echo "[2/4] Creating dataset: $DATASET"

bq mk \
  --dataset \
  --location="$LOCATION" \
  --description="Raw landing zone for US Aviation Analytics project. Contains unmodified BTS source data." \
  "$PROJECT_ID:$DATASET"

echo "      Dataset '$DATASET' created."

# Step 3: Create on_time_performance table
echo ""
echo "[3/4] Creating table: on_time_performance"
echo "      Partitioning : flight_date (DATE)"
echo "      Clustering   : reporting_airline, origin, dest"

bq mk \
  --table \
  --description="BTS Airline On-Time Performance data 2019-2023. One row = one scheduled flight segment. Partitioned by flight_date, clustered by reporting_airline/origin/dest." \
  --time_partitioning_field="FlightDate" \
  --time_partitioning_type="DAY" \
  --clustering_fields="Reporting_Airline,Origin,Dest" \
  --schema="$SCHEMA_DIR/on_time_performance.json" \
  "$PROJECT_ID:$DATASET.on_time_performance"

echo "       Table 'on_time_performance' created."

# Step 4: Create lookup tables
echo ""
echo "[4/4] Creating lookup tables"

bq mk \
  --table \
  --description="BTS airline code to full name lookup table." \
  --schema="$SCHEMA_DIR/airline_lookup.json" \
  "$PROJECT_ID:$DATASET.airline_lookup"

echo "      Table 'airline_lookup' created."

bq mk \
  --table \
  --description="BTS airport IATA code to city/airport name lookup table." \
  --schema="$SCHEMA_DIR/airport_lookup.json" \
  "$PROJECT_ID:$DATASET.airport_lookup"

echo "       Table 'airport_lookup' created."

# Final Summary
echo " Setup Complete!"
echo "========================================"
echo " $DATASET.on_time_performance  (partitioned + clustered)"
echo " $DATASET.airline_lookup"
echo " $DATASET.airport_lookup"