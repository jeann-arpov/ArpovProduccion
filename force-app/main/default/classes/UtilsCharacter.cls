/**
* @author Maximo Martinez
* @date 06/06/2014
* @description Clase Auxiliar que contiene utilidades para trabajar a nivel caracter con una cadena
*/
public class UtilsCharacter {
    
    private static final Map<String,Integer> charToAscii = new Map<String,Integer>();
    private static final Map<Integer,String> asciiToChar = new Map<Integer,String>();
    
    public static Integer toAscii(String character){
        if(charToAscii.containsKey(character)){
            return charToAscii.get(character);
        }
        return -1; 
    }
    
    public static String toChar(Integer ascii){
        if(ascii <= 0 || ascii > 255){
            return null;    
        }
        if(asciiToChar.containsKey(ascii)){
            return asciiToChar.get(ascii);
        }
        return null; 
    }
   
    static{
        
        charToAscii.put(null, 0);
        charToAscii.put('\t', 9);
        charToAscii.put('\n', 10);
        charToAscii.put('\f', 12);
        charToAscii.put('\r', 13);
        charToAscii.put(' ', 32);
        charToAscii.put('!', 33);
        charToAscii.put('"', 34);
        charToAscii.put('#', 35);
        charToAscii.put('$', 36);
        charToAscii.put('%', 37);
        charToAscii.put('&', 38);
        charToAscii.put('\'', 39);
        charToAscii.put('(', 40);
        charToAscii.put(')', 41);
        charToAscii.put('*', 42);
        charToAscii.put('+', 43);
        charToAscii.put(',', 44);
        charToAscii.put('-', 45);
        charToAscii.put('.', 46);
        charToAscii.put('/', 47);
        charToAscii.put('0', 48);
        charToAscii.put('1', 49);
        charToAscii.put('2', 50);
        charToAscii.put('3', 51);
        charToAscii.put('4', 52);
        charToAscii.put('5', 53);
        charToAscii.put('6', 54);
        charToAscii.put('7', 55);
        charToAscii.put('8', 56);
        charToAscii.put('9', 57);
        charToAscii.put(':', 58);
        charToAscii.put(';', 59);
        charToAscii.put('<', 60);
        charToAscii.put('=', 61);
        charToAscii.put('>', 62);
        charToAscii.put('?', 63);
        charToAscii.put('@', 64);
        charToAscii.put('A', 65);
        charToAscii.put('B', 66);
        charToAscii.put('C', 67);
        charToAscii.put('D', 68);
        charToAscii.put('E', 69);
        charToAscii.put('F', 70);
        charToAscii.put('G', 71);
        charToAscii.put('H', 72);
        charToAscii.put('I', 73);
        charToAscii.put('J', 74);
        charToAscii.put('K', 75);
        charToAscii.put('L', 76);
        charToAscii.put('M', 77);
        charToAscii.put('N', 78);
        charToAscii.put('O', 79);
        charToAscii.put('P', 80);
        charToAscii.put('Q', 81);
        charToAscii.put('R', 82);
        charToAscii.put('S', 83);
        charToAscii.put('T', 84);
        charToAscii.put('U', 85);
        charToAscii.put('V', 86);
        charToAscii.put('W', 87);
        charToAscii.put('X', 88);
        charToAscii.put('Y', 89);
        charToAscii.put('Z', 90);
        charToAscii.put('[', 91);
        charToAscii.put('\\', 92);
        charToAscii.put(']', 93);
        charToAscii.put('^', 94);
        charToAscii.put('_', 95);
        charToAscii.put('`', 96);
        charToAscii.put('a', 97);
        charToAscii.put('b', 98);
        charToAscii.put('c', 99);
        charToAscii.put('d', 100);
        charToAscii.put('e', 101);
        charToAscii.put('f', 102);
        charToAscii.put('g', 103);
        charToAscii.put('h', 104);
        charToAscii.put('i', 105);
        charToAscii.put('j', 106);
        charToAscii.put('k', 107);
        charToAscii.put('l', 108);
        charToAscii.put('m', 109);
        charToAscii.put('n', 110);
        charToAscii.put('o', 111);
        charToAscii.put('p', 112);
        charToAscii.put('q', 113);
        charToAscii.put('r', 114);
        charToAscii.put('s', 115);
        charToAscii.put('t', 116);
        charToAscii.put('u', 117);
        charToAscii.put('v', 118);
        charToAscii.put('w', 119);
        charToAscii.put('x', 120);
        charToAscii.put('y', 121);
        charToAscii.put('z', 122);
        charToAscii.put('{', 123);
        charToAscii.put('|', 124);
        charToAscii.put('}', 125);
        charToAscii.put('~', 126);
        charToAscii.put('Ç', 128);
        charToAscii.put('ü', 129);
        charToAscii.put('é', 130);
        charToAscii.put('â', 131);
        charToAscii.put('ä', 132);
        charToAscii.put('à', 133);
        charToAscii.put('å', 134);
        charToAscii.put('ç', 135);
        charToAscii.put('ê', 136);
        charToAscii.put('ë', 137);
        charToAscii.put('è', 138);
        charToAscii.put('ï', 139);
        charToAscii.put('î', 140);
        charToAscii.put('ì', 141);
        charToAscii.put('Ä', 142);
        charToAscii.put('Å', 143);
        charToAscii.put('É', 144);
        charToAscii.put('æ', 145);
        charToAscii.put('Æ', 146);
        charToAscii.put('ô', 147);
        charToAscii.put('ö', 148);
        charToAscii.put('ò', 149);
        charToAscii.put('û', 150);
        charToAscii.put('ù', 151);
        charToAscii.put('ÿ', 152);
        charToAscii.put('Ö', 153);
        charToAscii.put('Ü', 154);
        charToAscii.put('¢', 155);
        charToAscii.put('£', 156);
        charToAscii.put('¥', 157);
        charToAscii.put('₧', 158);
        charToAscii.put('ƒ', 159);
        charToAscii.put('á', 160);
        charToAscii.put('í', 161);
        charToAscii.put('ó', 162);
        charToAscii.put('ú', 163);
        charToAscii.put('ñ', 164);
        charToAscii.put('Ñ', 165);
        charToAscii.put('ª', 166);
        charToAscii.put('º', 167);
        charToAscii.put('¿', 168);
        charToAscii.put('⌐', 169);
        charToAscii.put('¬', 170);
        charToAscii.put('½', 171);
        charToAscii.put('¼', 172);
        charToAscii.put('¡', 173);
        charToAscii.put('«', 174);
        charToAscii.put('»', 175);
        charToAscii.put('░', 176);
        charToAscii.put('▒', 177);
        charToAscii.put('▓', 178);
        charToAscii.put('│', 179);
        charToAscii.put('┤', 180);
        charToAscii.put('╡', 181);
        charToAscii.put('╢', 182);
        charToAscii.put('╖', 183);
        charToAscii.put('╕', 184);
        charToAscii.put('╣', 185);
        charToAscii.put('║', 186);
        charToAscii.put('╗', 187);
        charToAscii.put('╝', 188);
        charToAscii.put('╜', 189);
        charToAscii.put('╛', 190);
        charToAscii.put('┐', 191);
        charToAscii.put('└', 192);
        charToAscii.put('┴', 193);
        charToAscii.put('┬', 194);
        charToAscii.put('├', 195);
        charToAscii.put('─', 196);
        charToAscii.put('┼', 197);
        charToAscii.put('╞', 198);
        charToAscii.put('╟', 199);
        charToAscii.put('╚', 200);
        charToAscii.put('╔', 201);
        charToAscii.put('╩', 202);
        charToAscii.put('╦', 203);
        charToAscii.put('╠', 204);
        charToAscii.put('═', 205);
        charToAscii.put('╬', 206);
        charToAscii.put('╧', 207);
        charToAscii.put('╨', 208);
        charToAscii.put('╤', 209);
        charToAscii.put('╥', 210);
        charToAscii.put('╙', 211);
        charToAscii.put('╘', 212);
        charToAscii.put('╒', 213);
        charToAscii.put('╓', 214);
        charToAscii.put('╫', 215);
        charToAscii.put('╪', 216);
        charToAscii.put('┘', 217);
        charToAscii.put('┌', 218);
        charToAscii.put('█', 219);
        charToAscii.put('▄', 220);
        charToAscii.put('▌', 221);
        charToAscii.put('▐', 222);
        charToAscii.put('▀', 223);
        charToAscii.put('α', 224);
        charToAscii.put('ß', 225);
        charToAscii.put('Γ', 226);
        charToAscii.put('π', 227);
        charToAscii.put('Σ', 228);
        charToAscii.put('σ', 229);
        charToAscii.put('µ', 230);
        charToAscii.put('τ', 231);
        charToAscii.put('Φ', 232);
        charToAscii.put('Θ', 233);
        charToAscii.put('Ω', 234);
        charToAscii.put('δ', 235);
        charToAscii.put('∞', 236);
        charToAscii.put('φ', 237);
        charToAscii.put('ε', 238);
        charToAscii.put('∩', 239);
        charToAscii.put('≡', 240);
        charToAscii.put('±', 241);
        charToAscii.put('≥', 242);
        charToAscii.put('≤', 243);
        charToAscii.put('⌠', 244);
        charToAscii.put('⌡', 245);
        charToAscii.put('÷', 246);
        charToAscii.put('≈', 247);
        charToAscii.put('°', 248);
        charToAscii.put('∙', 249);
        charToAscii.put('·', 250);
        charToAscii.put('√', 251);
        charToAscii.put('ⁿ', 252);
        charToAscii.put('²', 253);
        charToAscii.put('■', 254);
        charToAscii.put('√', 255);
        
        for(String key : charToAscii.keySet()){
            asciiToChar.put(charToAscii.get(key), key);    
        }

        
    }    

    
}