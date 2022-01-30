package com.andre.casm;

/**
 *
 * @author Andre
 */
public class Pair<K, V> {
	public K key;
	public V value;

	public Pair(){}
	
	public Pair(K k, V v){
		key = k;
		value = v;
	}
}
