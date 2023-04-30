package com.andre.pasme;

/**
 * Thrown whenever a needed program/extension isn't found. In Pasme, this is
 * generally thrown because of a misconfigured assembler.
 * <br>
 * <br> Last edit: 29/04/2023
 * 
 * @author André Morales
 */
public class ProgramNotFoundException extends RuntimeException {
	public ProgramNotFoundException(){}
	public ProgramNotFoundException(String str) { super(str); }
	public ProgramNotFoundException(Throwable cause) { super(cause); }
}