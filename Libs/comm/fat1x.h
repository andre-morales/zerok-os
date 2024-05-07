#ifndef FAT1X_H
#define FAT1X_H 1

EXTERN FATFS.LocateFile
EXTERN FATFS.ReadClusterChain
EXTERN FATFS.Initialize

EXTERN FATFS.beginningSct
EXTERN FATFS.clusterBuffer
EXTERN FATFS.vars_begin
EXTERN FATFS.vars_end
EXTERN FATFS.clusterBits
EXTERN FATFS.label
EXTERN FATFS.fatSct
EXTERN FATFS.rootDirSct
EXTERN FATFS.dataAreaSct
EXTERN FATFS.reservedLogicalSectors
EXTERN FATFS.totalLogicalSectors
EXTERN FATFS.fats
EXTERN FATFS.bytesPerLogicalSector
EXTERN FATFS.logicalSectorsPerCluster
EXTERN FATFS.bytesPerCluster
EXTERN FATFS.logicalSectorsPerFAT

#endif