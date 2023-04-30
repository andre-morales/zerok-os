package com.andre.pasme;

/**
 * Thrown whenever the assembler extension fails. Could be for any number of
 * reasons, but generally its because of bad assembly syntax.
 * <br>
 * <br> Last edit: 29/04/2023
 * 
 * @author André Morales
 */
public class AssemblerException extends RuntimeException {
	public AssemblerException(){}
	public AssemblerException(String str) { super(str); }
	public AssemblerException(Throwable cause) { super(cause); }
}