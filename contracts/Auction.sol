// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.2 <0.9.0;

/// @title Subasta
/// @notice Contrato inteligente para gestionar una subasta con comisión y extensión de tiempo.
contract Auction {
    // --- Variables de Estado ---

    /// @dev Dirección del organizador que recibirá los fondos del ganador y las comisiones.
    address payable public organizer;

    /// @dev Tiempo límite para recibir ofertas (timestamp UNIX).
    uint256 public auctionEndTime;

    /// @dev Dirección del postor con la oferta más alta actual.
    address public highestBidder;

    /// @dev Cantidad de la oferta más alta actual (en Wei).
    uint256 public highestBid;

    /// @dev Mapeo para guardar las ofertas de los postores que fueron superados,
    ///      permitiéndoles retirar el 98% de su último monto ofertado.
    mapping(address => uint256) public pendingReturns;

    /// @dev Indica si la subasta ha finalizado para evitar llamadas repetidas a auctionEnd.
    bool public ended; // Se hace pública para que el estado pueda ser consultado fácilmente.

    // --- Variables Adicionales para Mostrar Ofertas ---
    /// @dev Array para almacenar las direcciones de todos los postores que han participado.
    ///      Se usa para poder iterar y mostrar todas las ofertas activas/relevantes.
    address[] public biddersList; 
    
    /// @dev Mapeo para almacenar la última oferta válida de cada postor.
    ///      Esto es útil para la función getBids().
    mapping(address => uint256) public latestBidOf;


    // --- Eventos ---

    /// @dev Emitido cuando se realiza una nueva oferta válida y superior.
    /// @param bidder La dirección del postor que realizó la oferta.
    /// @param amount El monto de la oferta.
    event HighestBidIncreased(address indexed bidder, uint256 amount); // 'indexed' para facilitar búsquedas en logs

    /// @dev Emitido cuando la subasta finaliza oficialmente.
    /// @param winner La dirección del postor ganador.
    /// @param amount La oferta final ganadora.
    event AuctionEnded(address indexed winner, uint256 amount); // 'indexed' para búsquedas

    /// @dev Emitido cuando se retiene el 2% de una oferta superada.
    /// @param bidder La dirección del postor cuyos fondos fueron parcialmente retenidos.
    /// @param amount La cantidad de Ether retenida (2%).
    event FundsRetained(address indexed bidder, uint256 amount); // 'indexed' para búsquedas

    /// @dev Emitido cuando el plazo de la subasta se extiende debido a una nueva oferta tardía.
    /// @param newEndTime El nuevo timestamp de finalización de la subasta.
    event AuctionTimeExtended(uint256 newEndTime);


    // --- Constructor ---

    /// @dev Constructor que inicializa el contrato con la duración de la subasta y la dirección del organizador.
    /// @param _biddingTime Tiempo en segundos que durará la subasta inicialmente.
    /// @param _organizer Dirección pagable que recibirá los fondos del ganador y las comisiones.
    constructor(uint256 _biddingTime, address payable _organizer) {
        require(_biddingTime > 0, "El tiempo de subasta debe ser mayor a cero.");
        require(_organizer != address(0), "La direccion del organizador no puede ser nula.");

        auctionEndTime = block.timestamp + _biddingTime;
        organizer = _organizer;
    }

    // --- Funciones de la Subasta ---

    /// @dev Permite a los participantes ofertar por el artículo.
    ///      Una oferta es válida si:
    ///      1. Se realiza mientras la subasta está activa.
    ///      2. Es mayor en al menos 5% que la mayor oferta actual.
    ///      3. Si se realiza en los últimos 10 minutos, extiende el plazo de la subasta 10 minutos más.
    function bid() external payable {
        // 1. Validar que la subasta está activa
        require(block.timestamp <= auctionEndTime, "Subasta ya finalizada.");
        require(msg.sender != address(0), "La direccion del postor no puede ser nula.");
        require(msg.value > 0, "La oferta debe ser mayor a cero."); // Ofertas deben tener valor

        // 2. Lógica para extender la subasta si la oferta se realiza en los últimos 10 minutos
        uint256 tenMinutesInSeconds = 10 minutes;

        // Solo extendemos si ya hay una oferta (no es la primera oferta)
        // y si el tiempo restante para la subasta es de 10 minutos o menos.
        if (highestBid != 0 && (auctionEndTime - block.timestamp <= tenMinutesInSeconds)) {
            auctionEndTime += tenMinutesInSeconds; // Extiende la subasta 10 minutos más
            emit AuctionTimeExtended(auctionEndTime); // Notifica la extensión
        }

        // 3. Validar que la nueva oferta supere la anterior en al menos un 5%
        // (Solo aplica si highestBid es > 0. Si es la primera oferta, cualquier valor > 0 es válido)
        if (highestBid > 0) { // Si ya hay una oferta anterior
             // Calculamos el 5% de la oferta más alta. highestBid * 5 / 100
             // Aseguramos que la nueva oferta sea al menos 'highestBid' más el 5% de 'highestBid'
            require(msg.value >= highestBid + (highestBid * 5 / 100), "La oferta debe ser al menos un 5% mayor que la oferta actual.");
        }


        // 4. Lógica de devolución para el anterior highestBidder (con comisión del 2%)
        if (highestBidder != address(0)) { // Si ya hay un postor anterior
            // Calcular el 98% de la oferta anterior para devolver
            uint256 amountToReturn = (highestBid * 98) / 100;
            // Calcular el 2% retenido (para el contrato)
            uint256 amountRetained = highestBid - amountToReturn;

            // Se guarda la oferta anterior (el 98%) para que el postor superado pueda retirarla
            pendingReturns[highestBidder] += amountToReturn;
            
            // Emitir evento para el 2% retenido, para transparencia
            emit FundsRetained(highestBidder, amountRetained);
        }
        
        // 5. Actualizar el estado con la nueva oferta más alta
        // Aseguramos que el postor actual no esté en la lista si ya ofertó
        bool bidderFound = false;
        for (uint i = 0; i < biddersList.length; i++) {
            if (biddersList[i] == msg.sender) {
                bidderFound = true;
                break;
            }
        }
        if (!bidderFound) {
            biddersList.push(msg.sender); // Añadir el postor a la lista si es nuevo
        }
        
        highestBidder = msg.sender;
        highestBid = msg.value;
        latestBidOf[msg.sender] = msg.value; // Almacenar la última oferta de este postor

        // Emitir evento para comunicar la nueva oferta más alta
        emit HighestBidIncreased(msg.sender, msg.value);
    }

    /// @dev Permite a los postores retirar las ofertas que fueron superadas (el 98% de ellas).
    /// @return bool Verdadero si el retiro fue exitoso, falso en caso contrario.
    function withdraw() external returns (bool) {
        uint256 amount = pendingReturns[msg.sender];
        require(amount > 0, "No tienes fondos pendientes para retirar."); // Asegura que haya algo que retirar

        // Prevenir reentradas: pone a cero el saldo antes de intentar enviar.
        pendingReturns[msg.sender] = 0;

        // Intentar enviar los fondos.
        // Se prefiere .call{value: amount}("") sobre .send(amount) para mayor control de errores.
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        
        if (!success) {
            // Si el envío falla, se revierte el estado para que el postor no pierda sus fondos.
            pendingReturns[msg.sender] = amount;
            revert("Fallo al enviar fondos."); // Revertir toda la transacción si falla el envío
        }
        return true;
    }

    /// @dev Finaliza la subasta y transfiere la oferta ganadora al organizador.
    ///      Solo puede ser llamada después de que auctionEndTime haya pasado y una sola vez.
    function auctionEnd() external {
        require(block.timestamp >= auctionEndTime, "Subasta aun no finalizo.");
        require(!ended, "Ya se llamo a auctionEnd.");
        
        // La subasta ha terminado
        ended = true;

        // Emitir el evento de subasta finalizada
        emit AuctionEnded(highestBidder, highestBid);

        // Transferir la oferta ganadora al organizador.
        // Si highestBid es 0 (no hubo ofertas), no se transfiere nada.
        if (highestBid > 0) {
            (bool success, ) = organizer.call{value: highestBid}("");
            require(success, "Fallo al transferir la oferta ganadora al organizador.");
        }
        
        // NOTA: Los 2% retenidos de las ofertas perdedoras quedan en el balance del contrato
        // y pueden ser reclamados por el organizador con withdrawRetainedFunds().
    }

    /// @dev Permite al organizador retirar el 2% acumulado de las ofertas perdidas.
    ///      Solo puede ser llamado por el organizador y después de que la subasta haya finalizado.
    function withdrawRetainedFunds() external {
        require(msg.sender == organizer, "Solo el organizador puede retirar fondos retenidos.");
        require(ended, "La subasta aun no ha finalizado."); // Solo se puede retirar despues de finalizada

        // Calcular el balance del contrato que NO es parte de pendingReturns.
        // Para esto, sumamos todos los pendingReturns para sustraerlos del balance total.
        // Esto es un enfoque simplificado. Un contador explícito de `totalRetainedFees`
        // sería más robusto para grandes cantidades de postores.
        uint256 totalPendingReturns = 0;
        for (uint i = 0; i < biddersList.length; i++) {
            totalPendingReturns += pendingReturns[biddersList[i]];
        }
        
        uint256 amountToWithdraw = address(this).balance - totalPendingReturns;

        require(amountToWithdraw > 0, "No hay fondos retenidos para retirar.");

        (bool success, ) = payable(organizer).call{value: amountToWithdraw}("");
        require(success, "Fallo al retirar fondos retenidos.");
    }

    /// @dev Devuelve el oferente ganador y el valor de la oferta ganadora.
    /// @return winner La dirección del postor ganador.
    /// @return amount El monto de la oferta ganadora.
    function getWinner() external view returns (address winner, uint256 amount) {
        // No se requiere que la subasta esté finalizada para ver el "ganador actual"
        // pero sí para confirmar que es el ganador final.
        // Podríamos añadir require(ended, "La subasta aun no ha finalizado para ver el ganador final.");
        // si queremos que solo se muestre el ganador al final.
        return (highestBidder, highestBid);
    }

    /// @dev Devuelve la lista de todos los postores y sus últimas ofertas válidas.
    /// @return _bidders Una lista de las direcciones de todos los postores.
    /// @return _bids Una lista con las últimas ofertas de cada postor, en el mismo orden que _bidders.
    function getBids() external view returns (address[] memory _bidders, uint256[] memory _bids) {
        uint256 numBidders = biddersList.length;
        _bidders = new address[](numBidders);
        _bids = new uint256[](numBidders);

        for (uint i = 0; i < numBidders; i++) {
            _bidders[i] = biddersList[i];
            _bids[i] = latestBidOf[biddersList[i]];
        }
        return (_bidders, _bids);
    }

    /// @dev Retorna el tiempo restante de la subasta en segundos.
    /// @return remainingTime La cantidad de segundos restantes hasta que la subasta termine.
    function getRemainingTime() external view returns (uint256 remainingTime) {
        if (block.timestamp >= auctionEndTime) {
            return 0;
        } else {
            return auctionEndTime - block.timestamp;
        }
    }
}