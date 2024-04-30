package com.andre.devtoolkit;

/**
 *
 * @author Andre
 */
public class Main {

	/**
	 * @param args the command line arguments
	 */
	public static void main(String[] args) {		
		args = new String[]{"burnvbr", "C:\\Data\\Andre\\Projects\\ZeroK\\OS\\Bootloader\\build\\bin\\bstrap\\boot.img", "-to", "C:\\Data\\Andre\\Projects\\ZeroK\\Test Machines\\vdisk.vhd", "-partition", "0"};
		new DevToolkitCLI().run(args);
	}
	
}
