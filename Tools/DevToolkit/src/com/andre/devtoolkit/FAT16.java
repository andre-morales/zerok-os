package com.andre.devtoolkit;

import java.io.File;
import java.nio.ByteBuffer;
import jdk.jshell.spi.ExecutionControl;

/**
 *
 * @author Andre
 */
public class FAT16 {

	public final DiskPartition partition;
	public int reservedSectors;
	
	public FAT16(DiskPartition partition) {
		this.partition = partition;
		
		reservedSectors = getReservedSectorCount();
		
		System.out.println("FAT16: Reserved sectors: " + reservedSectors);
	}
	
	private int getReservedSectorCount() {
		var bytes = DiskBurner.readBytes(partition.disk, partition.startSector * 0x200 + 0x0E, 2);
		return Numbers.byteArrayToShort(bytes, 0);
	}
	
	public void burnVBR(File input, int inputOffset) {
		long inputSize = input.length();
		long startByte = partition.startSector * 0x200L;
		
		if (inputSize - 0x3E > 0x1C2) {
			throw new RuntimeException("Bootloader input size would overwrite data after the VBR. Data size: [" + inputSize + "]");
		}
		
		// Jump instruction start
		DiskBurner.transferFiles(input, inputOffset + 0x00, partition.disk, startByte + 0x00, 3);
		
		// Bootloader body
		DiskBurner.transferFiles(input, inputOffset + 0x3E, partition.disk, startByte + 0x3E, inputSize - 0x3E);
	}	
	
	public void burnReservedSectors(File input, int inputOffset) {
		long inputSize = input.length();
		long startByte = (partition.startSector + 1) * 0x200L;
		
		int inputSectors = (int)(inputSize / 512 + 1);
		
		// Reserved sector count is inferior to the required
		if (reservedSectors - 1 < inputSectors) {
			expandReservedSectors(inputSectors);
		}
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
}
