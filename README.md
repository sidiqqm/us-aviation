## 7. Business Background & Project Definition

### 7.1 Business Background

**Nama Project:** US Aviation Analytics Airline On-Time Performance Intelligence  
**Domain:** Transportation Analytics / Aviation Business Intelligence  
**Periode Analisis:** Januari 2019 — Desember 2023 (5 tahun penuh)

Industri penerbangan domestik AS mengoperasikan lebih dari 45.000 penerbangan per hari dan melayani lebih dari 900 juta penumpang per tahun pada periode sebelum COVID-19. Kinerja ketepatan waktu (*on-time performance*) merupakan salah satu KPI operasional paling kritis dalam industri penerbangan karena berpengaruh terhadap:

- Kepuasan penumpang
- Efisiensi operasional
- Biaya operasional maskapai
- Pemanfaatan kapasitas bandara
- Reputasi dan daya saing maskapai

Bureau of Transportation Statistics (BTS) secara resmi mengumpulkan dan mempublikasikan data kinerja penerbangan secara berkala. Data tersebut digunakan oleh regulator, maskapai, bandara, konsultan, dan analis untuk mendukung pengambilan keputusan berbasis data.

Project ini memanfaatkan data **Airline On-Time Performance** BTS selama Januari 2019 hingga Desember 2023 untuk menganalisis performa penerbangan, akar penyebab keterlambatan, perbedaan kinerja antar maskapai dan bandara, pola temporal, dampak COVID-19, serta proyeksi performa jangka pendek.

---

### 7.2 Stakeholder Analysis

| Stakeholder | Peran | Primary Interest | Level of Detail |
|---|---|---|---|
| **Airline Operations VP** | Decision Maker | Delay reduction, cost efficiency | Executive + Operational |
| **Airport Operations Manager** | Decision Maker | Gate utilization, congestion | Operational |
| **Revenue Management Team** | Influencer | Delay impact on booking behavior | Trend |
| **Route Planning Analyst** | Operational User | Chronic delay routes, capacity | Detail |
| **Regulatory Affairs Team** | Compliance | DOT reporting, benchmarking | Compliance |
| **C-Suite / Board** | Executive Sponsor | Strategic KPIs, year-over-year performance | Executive |

---

### 7.3 Business Problem

Industri penerbangan AS menghadapi tantangan ketepatan waktu yang kompleks dan multidimensional. Meskipun data penerbangan tersedia secara publik, sebagian besar analisis hanya berfokus pada agregasi sederhana tanpa menggali:

- Akar penyebab utama keterlambatan
- Perubahan pola delay dari waktu ke waktu
- Perbedaan performa antar maskapai
- Bandara dan rute dengan masalah keterlambatan kronis
- Hubungan antara volume penerbangan dan tingkat keterlambatan
- Dampak COVID-19 terhadap performa operasional
- Trajektori pemulihan industri setelah pandemi

#### Problem Statement

> Maskapai penerbangan dan operator bandara domestik AS tidak memiliki visibilitas yang cukup terhadap *driver* utama keterlambatan penerbangan, tren jangka panjang, serta dampak komprehensif dari disrupsi besar seperti COVID-19 terhadap kinerja operasional. Ketiadaan analisis tersebut menghambat pengambilan keputusan berbasis data untuk meningkatkan *on-time performance* secara sistematis.

---

### 7.4 Business Objectives

Project ini menggunakan framework **SMART** untuk memastikan tujuan analisis terukur dan relevan terhadap kebutuhan bisnis.

#### Objective 1 Delay Driver Identification

Mengidentifikasi dan mengkuantifikasi penyebab utama keterlambatan penerbangan berdasarkan data BTS 2019–2023 sehingga manajemen dapat memprioritaskan area intervensi yang memiliki dampak terbesar.

#### Objective 2 Temporal Pattern Analysis

Memahami pola musiman dan siklikal dalam *on-time performance* untuk mendukung perencanaan kapasitas dan manajemen operasional.

#### Objective 3 COVID-19 Impact Analysis

Menganalisis dampak COVID-19 terhadap volume penerbangan dan kinerja operasional industri penerbangan AS serta mengukur trajektori pemulihan selama 2022–2023.

#### Objective 4 Performance Benchmarking

Membandingkan *on-time performance* antar maskapai dan bandara untuk mengidentifikasi benchmark, performance gap, dan potential improvement areas.

#### Objective 5 Short-Term Forecasting

Memproyeksikan tren *on-time performance* jangka pendek berdasarkan pola historis, khususnya tren 2022–2023, sebagai masukan untuk perencanaan strategis.

---

### 7.5 Business Questions

Project ini dirancang untuk menjawab **12 Business Questions** berikut secara sistematis.

#### General Performance

**BQ-01.** Bagaimana tren *On-Time Performance (OTP)* penerbangan domestik AS dari 2019 hingga 2023?

**BQ-02.** Berapa rata-rata durasi keterlambatan kedatangan, dan bagaimana distribusinya?

#### Delay Causes

**BQ-03.** Apa penyebab terbesar keterlambatan penerbangan — *carrier delay*, weather, NAS, late aircraft, atau security?

**BQ-04.** Apakah proporsi penyebab keterlambatan berubah secara signifikan dari tahun ke tahun?

#### Airline Performance

**BQ-05.** Maskapai mana yang memiliki OTP terbaik dan terburuk secara konsisten?

**BQ-06.** Apakah terdapat perbedaan kinerja yang signifikan secara statistik antar maskapai besar?

#### Airport & Route Performance

**BQ-07.** Bandara mana yang paling sering menjadi origin keterlambatan sistemik?

**BQ-08.** Rute mana yang memiliki *chronic delay problem*?

#### Temporal Analysis

**BQ-09.** Apakah keterlambatan bersifat musiman? Bulan dan hari mana yang paling parah?

**BQ-10.** Bagaimana COVID-19 memengaruhi volume penerbangan dan OTP pada 2020–2021?

#### Correlation Analysis

**BQ-11.** Apakah terdapat korelasi antara volume penerbangan (*load*) dan tingkat keterlambatan?

#### Forecasting

**BQ-12.** Berdasarkan tren 2022–2023, bagaimana proyeksi OTP untuk 12 bulan ke depan?

---

### 7.6 KPI Definitions

| KPI | Definisi Bisnis | Formula | Target / Benchmark |
|---|---|---|---|
| **On-Time Arrival Rate (OTA)** | Persentase penerbangan yang tiba ≤15 menit dari jadwal | `Flights with ARR_DELAY <= 15 / Total Operated Flights` | ≥ 80% (DOT benchmark) |
| **Average Arrival Delay** | Rata-rata menit keterlambatan kedatangan pada penerbangan yang terlambat | `AVG(ARR_DELAY) WHERE ARR_DELAY > 15` | ≤ 45 menit |
| **Cancellation Rate** | Persentase penerbangan yang dibatalkan | `Cancelled Flights / Scheduled Flights` | ≤ 2% |
| **Carrier Delay Contribution** | Proporsi menit delay yang disebabkan oleh maskapai | `SUM(CARRIER_DELAY) / SUM(Total Delay Minutes)` | Tracking |
| **Weather Delay Contribution** | Proporsi menit delay yang disebabkan oleh cuaca | `SUM(WEATHER_DELAY) / SUM(Total Delay Minutes)` | Tracking |
| **NAS Delay Contribution** | Proporsi menit delay akibat National Air System | `SUM(NAS_DELAY) / SUM(Total Delay Minutes)` | Tracking |
| **Late Aircraft Delay Contribution** | Proporsi menit delay akibat pesawat terlambat dari penerbangan sebelumnya | `SUM(LATE_AIRCRAFT_DELAY) / SUM(Total Delay Minutes)` | Tracking |
| **Monthly Flight Volume** | Total penerbangan yang dioperasikan setiap bulan | `COUNT(flights) WHERE CANCELLED = 0` | Tracking |

> **Definition Note:** Project ini menggunakan definisi *on-time* sebagai penerbangan yang tiba dalam waktu maksimal 15 menit dari jadwal, dan definisi tersebut diterapkan secara konsisten di seluruh analisis.

---

### 7.7 Scope

#### In Scope

Project mencakup:

- Penerbangan domestik AS dengan origin dan destination di dalam AS
- Periode Januari 2019 — Desember 2023
- Seluruh carrier yang dilaporkan kepada BTS, termasuk major dan regional carriers
- Flight delay analysis
- Flight cancellation analysis
- Delay cause analysis
- Airline performance comparison
- Airport performance comparison
- Route performance analysis
- Temporal trend analysis
- COVID-19 impact analysis
- Correlation analysis antara flight volume dan delay
- Simple non-ML forecasting untuk OTP projection

#### Out of Scope

Project tidak mencakup:

- Penerbangan internasional
- Data harga tiket
- Revenue/pricing analytics berbasis DB1B
- Data cargo/freight
- Real-time flight data
- Machine learning
- Predictive modeling
- Analisis keuangan maskapai seperti revenue dan cost

---

# 8. Dataset Selection — Evaluation & Decision

### 8.1 BTS Dataset Candidates

Beberapa dataset BTS dievaluasi berdasarkan relevansi terhadap business objectives dan business questions project.

| Dataset | Deskripsi | Kekuatan | Kelemahan |
|---|---|---|---|
| **Airline On-Time Performance** | Data ketepatan waktu setiap penerbangan per segmen | Sangat granular, kaya dimensi, langsung menjawab delay analytics | File besar per bulan |
| **Air Carrier Statistics (T-100)** | Data kapasitas, load factor, dan statistik carrier | Bagus untuk capacity analysis | Tidak memiliki delay breakdown |
| **Origin & Destination Survey (DB1B)** | Data fare dan itinerary penumpang per quarter | Bagus untuk revenue/pricing analytics | Tidak memiliki delay data dan format lebih kompleks |
| **Border Crossing Entry Data** | Data lalu lintas perbatasan darat | Berguna untuk transportation analysis | Tidak relevan dengan aviation focus |
| **National Transit Database** | Data transportasi publik | Berguna untuk transit analytics | Tidak relevan dengan aviation focus |

---
