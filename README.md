# pen-impound

A modern, server-sided impound system built for **Qbox (qbx_core)**, featuring a clean **NUI interface** for impounding, retrieving (paid), and releasing vehicles.

Includes staff tooling, full impound history, advanced search, and activity logs

# Preview

<img width="666" height="652" alt="Screenshot 2026-01-18 203329" src="https://github.com/user-attachments/assets/d632463c-83dc-4575-9400-0dea0faa35f1" />
<img width="698" height="660" alt="Screenshot 2026-01-18 203356" src="https://github.com/user-attachments/assets/cdd317b8-0cc6-409f-bc34-cf5850d8d174" />

Police / Tow UI - https://streamable.com/718rr5
Normal User - https://streamable.com/sx145t

---

## Features

* Impound nearby vehicles via NUI form

* Reason required, optional report ID
* Paid vehicle retrieval (cash / bank supported)
* Staff release with no charge
* Staff impound history (released vehicles included)
* Search by:
  * Plate
  * Owner name
  * Vehicle model
  * Report ID
  * Citizen ID

* Date filters:
  * Today
  * This week
  * Overdue
  
* Activity logs (last 48 hours)
* Multiple impound lots with configurable spawn points
* Uses **ox_lib** callbacks and notifications throughout

---

## Dependencies

* **qbx_core**
* **ox_lib**
* **oxmysql**
* **qbx_vehiclekeys**

---

## Installation

### 1) Download

Download the latest release of **pen-impound**.

### 2) Import the SQL

Import the provided SQL file into your database.

> This creates the impound table used to store vehicle data, history, and logs.

### 3) Configure

Edit `config.lua` to suit your server:

* Impound locations
* Vehicle spawn points
* Authorized jobs
* Fees and limits

---

### Impound Zones & Spawns

Supports multiple impound lots, each with its own retrieval spawn points.

---

## Usage

### Impounding (Staff)

* Use the impound keybind or command
* Fill out the impound form
* Vehicle is removed and stored
* UI closes automatically on success

### Retrieving (Players)

* Visit an impound lot
* Select vehicle
* Pay fee and retrieve
* UI closes on success

### Releasing (Staff)

* Open the retrieve UI
* Select a vehicle
* Release with no charge
* UI remains open and refreshes automatically
