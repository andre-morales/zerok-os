package com.andre.devtoolkit;

import java.io.File;
import java.io.IOException;
import java.nio.ByteBuffer;
import java.nio.channels.FileChannel;
import java.nio.channels.SeekableByteChannel;
import java.nio.file.StandardOpenOption;

/**
 *
 * @author Andre
 */
public class DiskBurner {
	static byte[] readBytes(File input, long srcOffset, int length) {
		try {
			var inputSize = input.length();
			var inputStream = FileChannel.open(input.toPath(), StandardOpenOption.READ);
			inputStream.position(srcOffset);
			
			// Prevent an overflow if the specified input offset and length would do so.
			length = (int)Math.min(inputSize - srcOffset, length);
			
			var bytes = new byte[length];
			
			// Byte reading loop
			var bb = ByteBuffer.allocate(length);
			int remaining = length;
			while (remaining > 0) {
				int b = inputStream.read(bb);
				if (b == -1) {
					throw new IOException("-1.");
				}
				
				remaining -= b;
			}
			
			bb.flip();
			bb.get(bytes, 0, (int)length);
			return bytes;
		} catch (IOException ex) {
			throw new RuntimeException(ex);
		}
	}
	
	static long transferFiles(File input, long srcOffset, File output, long dstOffset, long length) {
		try {
			// Open output
			var outputStream = FileChannel.open(output.toPath(), StandardOpenOption.WRITE);
			
			// Open input file
			var inputSize = input.length();
			var inputStream = FileChannel.open(input.toPath(), StandardOpenOption.READ);
			
			// Prevent an overflow if the specified input offset and length would do so.
			long len = Math.min(inputSize - srcOffset, length);	
			
			// Burn
			long written = DiskBurner.transferChannels(inputStream, srcOffset, outputStream, dstOffset, len);
			
			// Release resources
			outputStream.close();
			inputStream.close();
			
			return written;
		} catch (IOException ex) {
			throw new RuntimeException(ex);
		}
	}
	
	static long transferChannels(SeekableByteChannel input, long srcOffset, SeekableByteChannel output, long dstOffset, long bytes) {
		try {
			// Set reading / writing points
			input.position(srcOffset);
			output.position(dstOffset);
			
			// Byte writing loop
			var bb = ByteBuffer.allocate(1);
			int b;
			long written = 0;
			for (long i = 0; i < bytes; i++) {
				while ((b = input.read(bb)) == 0) {
					if (b == -1) {
						throw new IOException("-1.");
					}
				}
				bb.flip();
				while (output.write(bb) == 0) {
				}
				bb.flip();
				
				written++;
			}
			return written;
		} catch (IOException ex) {
			throw new RuntimeException(ex);
		}
	}
}
