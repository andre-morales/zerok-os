package com.andre.devtoolkit;

import java.io.File;

/**
 *
 * @author Andre
 */
public class DiskPartition {
	public File disk;
	public int id;
	public int startSector;
	public int sizeInSectors;
	public byte type;
	
	public DiskPartition() {}

	@Override
	public String toString() {
		var typeStr = getTypeDescription();
		var sizeStr = getSizeDescription();
		return String.format("[%d] '%s' : %s : 0x%x", id, typeStr, sizeStr, startSector);
	}
	
	private String getSizeDescription() {
		int sizeInKB = sizeInSectors / 2;
		if (sizeInKB < 8192) {
			return sizeInKB + " KiB";
		}
		
		int sizeInMB = sizeInKB / 1024;
		if (sizeInMB < 8192) {
			return sizeInMB + " MiB";
		}
		
		int sizeInGB = sizeInMB / 1024;
		return sizeInGB + " GiB";
	}
	
	private String getTypeDescription() {
		return switch (type & 0xFF) {
			case 0x00 -> "Empty";
			case 0x0E -> "FAT 16";
			default -> "Unknown";
		};
	}
}
