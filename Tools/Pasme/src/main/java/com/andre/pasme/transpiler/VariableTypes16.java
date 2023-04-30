package com.andre.pasme.transpiler;

import java.util.HashMap;
import java.util.Map;

/**
 
 * Util class to store all the sizes of the variables types present in the Pasme
 * language. This class considers pointers as 16 bits long.
 * <br>
 * <br>Last edit: 29/04/2023
 * 
 * @author André Morales
 */
public class VariableTypes16 {
	public static Map<String, Integer> get(){
		var map = new HashMap<String, Integer>() {};
		
		map.put("void", 0);
		map.put("byte", 1);
		map.put("bool", 1);
		map.put("char", 1);
		map.put("short", 2);
		map.put("int", 4);
		map.put("long", 8);

		map.put("word", 2);
		map.put("dword", 4);
		map.put("qword", 8);
		
		map.put("void*", 2);
		map.put("byte*", 2);
		map.put("char*", 2);
		
		return map;
	}
}
