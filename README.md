# KipuBankV2
*Modulo 3 Solidity 2025*


##Mejoras
-Se creo un token usdc ficticio para interactuar con él. usdctoken: 0x8f3f2404b48c8ff50D474069a558a541667f46b8
-Se agrega soporte para roles.
-Se agrega soporte multitoken con un token admás de eth.
-Se agrega un oráculo basado en feeds de Chainlink para obtener el precio de eth.
-Se corrigieron errores check-interact-effect

##Instrucciones de despliegue e interacción.
1. Se desplegará en Sepolia.
2. Subir código a Remix.
3. Conectar billetera Metamask para pagar el costo de la publicación en la red Sepolia.
4. Compilar código. En este caso se compila con la versión **0.8.30 + commit.73712a01**
5. Una vez compilado se obtendrá la dirección del contrato. En este caso es: 0x49e762d6687A1b3c2e3B77727D00bB31CBDE2CdA
6. Para verificar el contrato hay que dirigirse a la testnet de sepolia https://sepolia.etherscan.io
    - Buscar en el buscador de contratos el nuestro.
    - Dirigirse a Contract y pegar el codigo del contrato y contestar las preguntas de verificación (versión de compilación, Type: Solidity Single File, tipo de licencia, aceptar términos y condiciones)
    - Pegar el ABI que se ha descargado.
    - En la siguiente página hay que pegar el código del contrato exactamente como estaba redactado y elegir la versión del EVM con la que se compiló (en nuestro caso Cancun).
    - Si todos los datos son correctos, el contrato quedará verificado con una tilde y aparecerá el Contract ABI en la página de confirmación.

## Cómo interactuar con el contrato.
   **Monto mínimo para ingresar 0.01 ETH**
### Funciones exclusivas:
-Consultas estadísticas como cantidades de retiros sólo con rol Accountant.


##Notas sobre decisiones de diseño importantes o trade-offs.
Se eliminaron los withdraws porque esto implica convertir nuevamente los tokens en Eth. 
El problema de esto es el cambio de precio de eth si este baja.
Podría darse el caso de que el precio de eth baje, entonces los tokens valen más que antes y tengo que devolver más eth de los que realmente tengo en el banco. Si el usuario deposita 0.1 eth, luego deposita otros 0.1 eth y los convierte en 400 usdc. Luego eth baja de precio y los 400usdc pasan a ser 0.11 eth y quiere recuperar el dinero, entonces tendría que devolver 0.21 eth cuando el banco tiene realmente 0.2.
Por eso se deshabilitaron los retiros aunque sí se realizan converciones entre eth y usdc.

-Se agregó soporte de roles de administrador para probar la función de retiro
-Se agregó función de accountant para que este rol pueda verificar las cantidades de depósitos y retiros realizados. Esto es exclusivo para que cualquier usuario no pueda ver los movimientos del banco.

##Contrato desplegado:
##Github del código fuente:


oracle: 0x09970E2AC5f8a6EE23bBD2DD0ca796Aa465fc42b
usdctoken: 0x8f3f2404b48c8ff50D474069a558a541667f46b8
kipubankv2 - 1: 0xCBE665EB6bB9b1840da900CD2b5E41CB1F545732
