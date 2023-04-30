package com.andre.pasme;

/**
 * @author André Morales
 * @version 1.0
 * 
 * Last edit: 29/04/2023
 * 
 * String utilities class.
 */
public class Str {
	private Str(){}
	
	/** @param str A string to test.
	 * @return true if the string has length 0 or equals null, false otherwise.
	 */
	public static boolean isNullOrEmpty(String str){
		return str == null || str.length() == 0;
	}
	
	/** @param c A character.
	 * @return Wether the given char is a ['] or a ["] character. */
	public static boolean isQuote(char c){
		return c == '"' || c == '\'';
	}
	
	/** @param input An input string to process.
	 * @param search What to look for in the input string.
	 * @return The remaining of the input string, or null if the search string was not found on the input. 
	 * 
	 * Finds the given search string in the input, and returns
	 * everything after the end of this string.
	 * 
	 * For example:
	 * <pre> {@code
	 * var input = "This is a piece of text.";
	 * var search = "pi"
	 * var result = remainingAfter(input, search);
	 * // result is "ece of text."
	 * } </pre>
	 */
	public static String remainingAfter(String input, String search){
		int i = input.indexOf(search);
		if (i == -1) return null;
		
		return input.substring(i + search.length());
	}
	
	/** Returns the input string from the first character until the first
	  * match with the search string.
	  * If the search string is not present on the input, the full input is
	  * returned. */
	public static String untilFirstMatch(String input, String search){
		var i = input.indexOf(search);
		if(i == -1) return input;
		return input.substring(0, i);
	}
	
	/** Returns the input string from the beginning index until the first
	  * match with the search string.
	  * If the search string is not present on the input, the input string is
	  * returned starting from the index. */
	public static String untilFirstMatch(String input, int fromIndex, String search){
		var i = input.indexOf(search, fromIndex);
		if(i == -1) return input.substring(fromIndex);
		return input.substring(fromIndex, i);
	}
	
	/** Returns the input string from the beginning index until the first
	  * match of the provided searches.
	  * If none of the search strings are present on the input, the input string is
	  * returned starting from the index. */
	public static String untilFirstMatch(String input, int fromIndex, String... searches){
		int index = Integer.MAX_VALUE;
		for(var str : searches){
			var i = input.indexOf(str, fromIndex);
			if(i != -1 && i < index) index = i;
		}
		
		if(index == Integer.MAX_VALUE) return input.substring(fromIndex);
		return input.substring(fromIndex, index);
	}
}
