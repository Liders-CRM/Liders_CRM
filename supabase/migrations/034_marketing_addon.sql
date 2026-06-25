-- Migration 034: add marketing_addon flag to tenants
ALTER TABLE tenants ADD COLUMN IF NOT EXISTS marketing_addon boolean NOT NULL DEFAULT false;
