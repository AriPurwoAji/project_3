package database

import (
	"context"
	"fmt"
	"log"
	"os"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
)

var DB *pgxpool.Pool

func Connect() (*pgxpool.Pool, error) {
	dsn := fmt.Sprintf(
		"host=%s port=%s dbname=%s user=%s password=%s sslmode=require",
		os.Getenv("DB_HOST"),
		os.Getenv("DB_PORT"),
		os.Getenv("DB_NAME"),
		os.Getenv("DB_USER"),
		os.Getenv("DB_PASSWORD"),
	)

	cfg, err := pgxpool.ParseConfig(dsn)
	if err != nil {
		return nil, fmt.Errorf("failed to parse db config: %w", err)
	}

	cfg.MinConns = 2                        // pre-warm 2 koneksi saat startup
	cfg.MaxConns = 10                       // maks koneksi concurrent
	cfg.MaxConnIdleTime = 5 * time.Minute   // tutup koneksi idle > 5 menit
	cfg.HealthCheckPeriod = 1 * time.Minute // ping periodik agar koneksi tetap hidup

	pool, err := pgxpool.NewWithConfig(context.Background(), cfg)
	if err != nil {
		return nil, fmt.Errorf("failed to create connection pool: %w", err)
	}

	if err := pool.Ping(context.Background()); err != nil {
		return nil, fmt.Errorf("failed to ping database: %w", err)
	}

	log.Println("✅ Database connected successfully")
	return pool, nil
}

func Close(pool *pgxpool.Pool) {
	pool.Close()
	log.Println("Database connection closed")
}

