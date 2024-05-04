package com.andre.devtoolkit;

import java.io.File;

/**
 *
 * @author Andre
 */
public class FAT16 {

	private final DiskPartition partition;
	private final int reservedSectors;
	
	public FAT16(DiskPartition partition) {
		if (partition.getType() != PartitionType.FAT16) throw new RuntimeException("Partition is not of FAT16 type.");
		this.partition = partition;
		
		reservedSectors = getReservedSectorCount();
	}
		
	public void burnVBR(File input, int inputOffset, long inputSize) {
		// Limit file size
		inputSize = capInputSize(input, inputSize);

		long startByte = partition.getFirstSector() * 0x200L;
		
		if (inputSize - 0x3E > 0x1C2) {
			throw new RuntimeException("Bootloader input size would overwrite data after the VBR. Data size: [" + inputSize + "]");
		}
		
		// Burn jump instruction start and the rest of the file body
		var disk = partition.getDisk();
		Burner.transfer(input, inputOffset + 0x00, disk, startByte + 0x00, 3);
		Burner.transfer(input, inputOffset + 0x3E, disk, startByte + 0x3E, inputSize - 0x3E);
	}	
	
	public void burnReservedSectors(File input, int inputOffset, long inputSize) {
		// Limit file size
		inputSize = capInputSize(input, inputSize);
			
		// Get position of the first byte of the sector after the VBR
		long diskOffset = (partition.getFirstSector() + 1) * 0x200L;
		int inputSectors = (int)(inputSize / 512 + 1);
		
		// Reserved sector count is inferior to the required amount
		if (reservedSectors - 1 < inputSectors) {
			expandReservedSectors(inputSectors);
		}
		
		// File body
		Burner.transfer(input, inputOffset, partition.getDisk(), diskOffset, inputSize);
	}
	
	private void expandReservedSectors(int sectors) {
		throw new CLIException("Reserved sector expansion not implemented yet.");
		
		/*if (reservedSectors - 1 >= sectors) return;
		
		var buffer1 = ByteBuffer.allocate((reservedSectors - 1 - sectors) * 512);
		var buffer2 = ByteBuffer.allocate((reservedSectors - 1 - sectors) * 512);
		
		long sector = partition.startSector + 1;
		while (sector < partition.startSector + partition.sizeInSectors) {
			
		}*/
	}
	
	private int getReservedSectorCount() {
		var bytes = Burner.readBytes(partition.getDisk(), partition.getFirstSector() * 0x200 + 0x0E, 2);
		return Numbers.byteArrayToShort(bytes, 0);
	}
	
	private static long capInputSize(File input, long size) {
		if (size < 0) return input.length();
		return Math.min(input.length(), size);
	}
}
