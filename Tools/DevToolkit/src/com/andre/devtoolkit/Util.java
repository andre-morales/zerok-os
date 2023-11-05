package com.andre.devtoolkit;

/**
 *
 * @author Andre
 */
public class Util {
	public static String toStringHexBytes(byte[] bytes) {
		var sb = new StringBuilder();
		
		for (byte b : bytes) {
			sb.append(String.format("%02X ", b));
		}
		
		return sb.toString();
	}
	
  public static int byteArrayToInt(byte[] bytes, int offset) {
        return  ((bytes[offset + 3] & 0xFF) << 24) |
                ((bytes[offset + 2] & 0xFF) << 16) |
                ((bytes[offset + 1] & 0xFF) << 8)  |
                ((bytes[offset + 0] & 0xFF) << 0);
    }

}
