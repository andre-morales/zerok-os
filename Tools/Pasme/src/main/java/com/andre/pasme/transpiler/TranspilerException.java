package com.andre.pasme.transpiler;

/**
 * Thrown in cases of improper usage of Pasm language syntax.
 * <br>
 * <br>Last edit: 29/04/2023
 * 
 * @author André Morales
 */
public class TranspilerException extends RuntimeException {

	public TranspilerException(String str) {
		super(str);
	}

}
