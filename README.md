# pen-impound

A modern, server-sided impound system built for **Qbox (qbx_core)**, featuring a clean **NUI interface** for impounding, retrieving (paid), and releasing vehicles.

Includes staff tooling, full impound history, advanced search, and activity logs

# Preview

<img width="666" height="652" alt="Screenshot 2026-01-18 203329" src="https://github.com/user-attachments/assets/fc421dc9-a57c-42a3-8d6f-99783802c1b8" />
<img width="698" height="660" alt="Screenshot 2026-01-18 203356" src="https://github.com/user-attachments/assets/6d244079-5e84-4c9c-aa85-89595082cc68" />

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
