-- CreateTable: add canonical pair key so 1:1 DM threads are unique per user pair.
-- Nullable for back-compat with pre-existing rows (Postgres allows multiple NULLs in a UNIQUE index).

-- AlterTable
ALTER TABLE "dm_threads" ADD COLUMN "pairKey" TEXT;

-- CreateIndex
CREATE UNIQUE INDEX "dm_threads_pairKey_key" ON "dm_threads"("pairKey");
