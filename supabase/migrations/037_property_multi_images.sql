-- Add image_urls array column to properties for multi-image support
ALTER TABLE properties ADD COLUMN IF NOT EXISTS image_urls text[] DEFAULT '{}';

-- Migrate existing single image_url to the array (for future data)
UPDATE properties SET image_urls = ARRAY[image_url] WHERE image_url IS NOT NULL AND array_length(image_urls, 1) IS NULL;
