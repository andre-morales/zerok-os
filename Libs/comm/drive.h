#ifndef DRIVE_H
#define DRIVE_H 1
EXTERN Drive.Init
EXTERN Drive.ReadSector
EXTERN Drive.CHS.GetProperties
EXTERN Drive.LBA.GetProperties

EXTERN Drive.id
EXTERN Drive.bufferPtr
EXTERN Drive.vars_begin
EXTERN Drive.vars_end
EXTERN Drive.CHS.bytesPerSector
EXTERN Drive.CHS.sectorsPerTrack
EXTERN Drive.CHS.headsPerCylinder
EXTERN Drive.CHS.cylinders
EXTERN Drive.LBA.available
EXTERN Drive.LBA.bytesPerSector
#endif