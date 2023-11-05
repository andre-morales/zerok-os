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
		args = new String[]{"partitions", "C:\\Data\\Andre\\Projects\\ZeroK\\Test Machines\\vdisk.vhd"};
		new DevToolkitCLI().run(args);
	}
	
}
