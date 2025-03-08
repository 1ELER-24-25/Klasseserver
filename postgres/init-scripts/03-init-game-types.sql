-- Insert game types
INSERT INTO gaming.game_types (name, description, default_elo, k_factor) VALUES
    ('FOOSBALL', 'Table football game, first to 10 goals wins', 1200, 40),
    ('CHESS', 'Classic chess game with standard rules', 1200, 20)
ON CONFLICT (name) DO UPDATE 
    SET description = EXCLUDED.description,
        default_elo = EXCLUDED.default_elo,
        k_factor = EXCLUDED.k_factor;

-- Verify initialization
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM gaming.game_types) THEN
        RAISE EXCEPTION 'Game types were not inserted properly';
    END IF;
END $$;