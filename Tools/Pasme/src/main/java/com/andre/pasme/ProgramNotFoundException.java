package com.andre.pasme;

/**
 *
 * @author Andre
 */
public class ProgramNotFoundException extends RuntimeException {
	public ProgramNotFoundException(){}
	public ProgramNotFoundException(String str) { super(str); }
	public ProgramNotFoundException(Throwable cause) { super(cause); }
}