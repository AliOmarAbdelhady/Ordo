-- AlterTable
ALTER TABLE "group_members" ADD COLUMN     "lastReadAt" TIMESTAMPTZ(3),
ADD COLUMN     "pinned" BOOLEAN NOT NULL DEFAULT false;
