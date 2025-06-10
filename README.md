# 🧾 Trabajo Final - Módulo 2: Contrato Inteligente de Subasta (Auction Smart Contract)

Este repositorio contiene la implementación de un **contrato inteligente de subasta abierta** desarrollado en Solidity, creado como parte del Trabajo Final del Módulo 2. El contrato `Auction.sol` ha sido diseñado para ser **robusto, seguro** y ofrecer **funcionalidades avanzadas** que brindan una experiencia de subasta completa y descentralizada en la blockchain.

## 🎯 Requisitos Generales y Enlaces del Proyecto

Aquí están las URLs para acceder al contrato desplegado y a este repositorio:

* **URL del Contrato en Sepolia Etherscan (Verificado):** [https://sepolia.etherscan.io/address/0x4dab63884584ef8f7e5315710527e37f6d00f186#code](https://sepolia.etherscan.io/address/0x4dab63884584ef8f7e5315710527e37f6d00f186#code)
* **URL de este Repositorio en Github:**  `https://github.com/CaosFq/SubastaSmartContractFinal`

---

## ⚙️ Funcionalidades Implementadas y Construcción de la Subasta

El contrato `Auction.sol` (`./contracts/Auction.sol` dentro de este repositorio) está construido sobre la siguiente lógica y componentes:

### **1. Variables de Estado: El "Cerebro" del Contrato**

Estas variables almacenan la información crítica y persistente de la subasta en la blockchain:

* `organizer` (address payable): Dirección de la cuenta que despliega el contrato y es el organizador de la subasta, quien recibirá la puja ganadora y las comisiones.
* `auctionEndTime` (uint256): El timestamp (momento exacto en segundos desde el 1 de enero de 1970) en el que la subasta debería finalizar.
* `highestBidder` (address): La dirección del postor que actualmente tiene la oferta más alta.
* `highestBid` (uint256): El valor actual (en Wei, la unidad más pequeña de Ether) de la oferta más alta.
* `pendingReturns` (mapping(address => uint256)): Un mapeo crucial que rastrea cuánto Ether (el 98% de ofertas superadas) debe ser devuelto a cada postor. Esto implementa el patrón de seguridad **"pull over push"** para prevenir ataques de reentrada.
* `ended` (bool): Un indicador booleano que señala si la subasta ya ha concluido (`true`) o no (`false`), controlando el flujo del contrato.
* `biddersList` (address[]): Un arreglo para almacenar las direcciones de todos los postores únicos que han participado en la subasta. Facilita la recuperación de una lista completa de participantes.
* `latestBidOf` (mapping(address => uint256)): Un mapeo que guarda la última oferta válida realizada por cada postor.

### **2. Eventos: La Voz del Contrato**

Los eventos son la forma en que el contrato se comunica con el "mundo exterior" (aplicaciones descentralizadas, exploradores de bloques, etc.), emitiendo "mensajes" registrables en la blockchain para notificar cambios importantes de estado.

* `HighestBidIncreased(address indexed bidder, uint256 amount)`: Emitido cada vez que un participante realiza una nueva oferta válida que supera la anterior.
* `AuctionEnded(address indexed winner, uint256 amount)`: Emitido cuando la subasta finaliza oficialmente, revelando al ganador y la puja final.
* `FundsRetained(address indexed bidder, uint256 amount)`: Emitido para transparentar cuándo y cuánto del 2% de comisión es retenido de una oferta superada.
* `AuctionTimeExtended(uint256 newEndTime)`: Emitido cuando el plazo de la subasta se extiende dinámicamente debido a una nueva oferta tardía.

### **3. Constructor: El Inicio de la Subasta**

```solidity
constructor(uint256 _biddingTime, address payable _organizer)
Propósito: Esta función se ejecuta una única vez al desplegar el contrato en la blockchain.
Construcción: Se encarga de inicializar el auctionEndTime (tiempo de duración inicial de la subasta) y de asignar la dirección del organizer. Incluye validaciones para asegurar que los parámetros iniciales sean correctos (ej., tiempo mayor a cero, dirección del organizador no nula).
4. function bid() external payable: Realizando una Oferta
Propósito: Permite a cualquier participante enviar Ether para realizar una oferta por el ítem subastado.
Construcción y Lógica Clave:
Validaciones Iniciales: Se verifica que la subasta esté activa, que el msg.sender (el postor) no sea nulo y que el valor de la oferta (msg.value) sea positivo.
Extensión Dinámica del Plazo (Soft Close): Si una oferta válida se realiza dentro de los últimos 10 minutos del auctionEndTime actual (y la subasta ya tiene al menos una oferta previa), el plazo se extiende automáticamente 10 minutos más. Esto promueve una competencia justa al final de la subasta.
Incremento Mínimo del 5%: La nueva oferta debe ser al menos un 5% mayor que la oferta más alta actual (highestBid). Si es la primera oferta de la subasta (highestBid es 0), esta regla no aplica, y cualquier oferta mayor a cero es válida.
Manejo de Devoluciones y Comisión del 2%: Cuando un postor es superado, el 98% de su última oferta válida se transfiere a su saldo pendingReturns (para que pueda retirarlo). El 2% restante se retiene dentro del contrato como comisión, y se registra mediante el evento FundsRetained.
Actualización del Estado: highestBidder y highestBid se actualizan con los datos del nuevo postor y su oferta.
Registro y Consulta de Postores: El postor actual se añade a la biddersList (si es un nuevo participante) y su última oferta se registra en latestBidOf para futuras consultas.
Notificación: Se emite HighestBidIncreased para notificar al mundo exterior sobre la nueva oferta.
5. function withdraw() external returns (bool): Retirando Fondos Pendientes
Propósito: Permite a los postores que han sido superados retirar el 98% de los fondos que el contrato les tiene pendientes.
Construcción y Seguridad: Esta función implementa el patrón de seguridad "pull over push": primero pone a cero el saldo a retirar (pendingReturns[msg.sender] = 0;) y luego intenta la transferencia de los fondos. Esto es una medida de seguridad crucial para prevenir ataques de reentrada. Utiliza payable(...).call{value}() para una transferencia robusta y revert() si el envío de Ether falla, garantizando la integridad de la transacción.
6. function auctionEnd() external: Finalizando la Subasta
Propósito: Finaliza oficialmente la subasta y transfiere la oferta ganadora al organizador.
Construcción y Lógica:
Validación: Solo puede ser llamada después de que el auctionEndTime haya transcurrido y, crucialmente, solo una vez (previene llamadas repetidas y manipulaciones de estado).
Cambio de Estado: Marca la variable ended como true, indicando que la subasta ha concluido.
Notificación: Emite el evento AuctionEnded, que incluye la dirección del highestBidder (ganador) y el highestBid (oferta final).
Transferencia de Fondos: Si hubo ofertas (highestBid > 0), la cantidad de la puja ganadora se transfiere al organizer utilizando una transferencia segura con payable(...).call{value}().
7. function withdrawRetainedFunds() external: Retirando Comisiones del Organizador
Propósito: Permite al organizer retirar el 2% de comisión acumulado de las ofertas perdidas que han quedado en el contrato.
Construcción y Lógica:
Validación: Solo el organizer puede llamar a esta función, y únicamente después de que la subasta haya finalizado (ended sea true).
Cálculo de Fondos: Suma todos los pendingReturns y los resta del balance total del contrato para estimar el monto de comisiones a retirar.
Transferencia Segura: Transfiere el monto calculado al organizer utilizando payable(...).call{value}().
8. Funciones de Consulta (view functions)
Estas funciones son view o pure, lo que significa que no modifican el estado de la blockchain y no cuestan gas al ser llamadas.

getWinner() external view returns (address winner, uint256 amount): Devuelve la dirección del postor con la oferta más alta actual y el valor de esa oferta. Permite ver el "ganador provisional" durante la subasta o confirmar el ganador final.
getBids() external view returns (address[] memory _bidders, uint256[] memory _bids): Proporciona una lista completa de todas las direcciones de los postores que han participado y sus respectivas últimas ofertas válidas. Esta implementación utiliza estructuras de datos auxiliares (biddersList y latestBidOf) para superar la limitación de la iteración directa de mapeos en Solidity.
getRemainingTime() external view returns (uint256 remainingTime): Calcula y devuelve el tiempo restante en segundos hasta que la subasta concluya. Si la subasta ya ha terminado, retorna 0.
Consideraciones de Seguridad y Robustez
El contrato está diseñado con un fuerte enfoque en la seguridad y la fiabilidad:

Validaciones Exhaustivas: Uso extensivo de sentencias require() en todas las funciones para validar condiciones de entrada, estados del contrato y proteger contra usos indebidos.
Prevención de Reentradas: Implementación del patrón "pull over push" en la función withdraw() para proteger contra una vulnerabilidad común en contratos inteligentes.
Transferencias Seguras: Uso de payable(...).call{value}() para todas las transferencias de Ether, que es el método recomendado y más robusto, con verificación de éxito para revertir transacciones si la transferencia falla.
Control de Estado: El uso de la variable ended y sus validaciones previene que la subasta se finalice o manipule después de su conclusión.
Manejo de Direcciones Nulas: Validaciones explícitas para direcciones no nulas (address(0)) y valores positivos (msg.value > 0).
Documentación Detallada
El código fuente está ampliamente documentado utilizando Natspec (/// @title, /// @notice, /// @dev, /// @param). Esto proporciona una descripción clara y detallada de cada variable, función y evento, haciendo que el contrato sea más comprensible, auditable y fácil de mantener para cualquier desarrollador o auditor.
