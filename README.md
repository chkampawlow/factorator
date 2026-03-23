# ⚡ Factorator

A modern invoicing platform built with a **Flutter mobile app** and a **PHP/MySQL backend API**.

<p align="center">
  <img alt="Flutter" src="https://img.shields.io/badge/Flutter-Mobile-blue?logo=flutter">
  <img alt="PHP" src="https://img.shields.io/badge/PHP-Backend-777BB4?logo=php">
  <img alt="MySQL" src="https://img.shields.io/badge/MySQL-Database-4479A1?logo=mysql">
  <img alt="JWT" src="https://img.shields.io/badge/Auth-JWT-black">
  <img alt="Status" src="https://img.shields.io/badge/Status-Active-success">
</p>

---

## ✨ Overview

Factorator is a full invoicing solution designed to manage:

- clients
- products
- invoices
- invoice items
- user profile and company information
- currency preferences
- PDF invoice generation

The project is split into two parts:

- **Flutter Frontend** → mobile application
- **PHP Backend** → REST-style API with MySQL

---

## 🧱 Architecture

```text
Factorator
├── flutter-app/
│   ├── lib/
│   ├── assets/
│   └── pubspec.yaml
│
└── php-api/
    ├── auth/
    ├── clients/
    ├── products/
    ├── invoices/
    ├── invoice_items/
    ├── user/
    ├── config/
    ├── .env
    └── static_token.php
