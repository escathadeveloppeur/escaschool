// lib/widgets/qr_scanner.dart

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'dart:io';

class QRScanner extends StatefulWidget {
  final Function(String) onScan;
  final VoidCallback onClose;

  const QRScanner({
    super.key,
    required this.onScan,
    required this.onClose,
  });

  @override
  _QRScannerState createState() => _QRScannerState();
}

class _QRScannerState extends State<QRScanner> {
  final TextEditingController _manualCodeController = TextEditingController();
  
  bool get _isMobile => Platform.isAndroid || Platform.isIOS;

  @override
  void dispose() {
    _manualCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isMobile) {
      return _buildDesktopView();
    }
    return _buildMobileScanner();
  }

  Widget _buildDesktopView() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scanner QR Code'),
        centerTitle: true,
        backgroundColor: Colors.blue,
        actions: [
          IconButton(
            icon: Icon(Icons.close),
            onPressed: () {
              widget.onClose();
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.qr_code_scanner, size: 80, color: Colors.blue),
              SizedBox(height: 24),
              Text(
                'Scanner QR code',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              Text(
                'Sur ordinateur, veuillez saisir manuellement le code QR.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
              SizedBox(height: 32),
              TextField(
                controller: _manualCodeController,
                decoration: InputDecoration(
                  labelText: 'Code QR (manuel)',
                  hintText: 'Entrez le code de l\'élève',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  prefixIcon: Icon(Icons.qr_code),
                ),
                onSubmitted: (value) {
                  if (value.isNotEmpty) {
                    widget.onScan(value);
                    Navigator.pop(context);
                  }
                },
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        if (_manualCodeController.text.isNotEmpty) {
                          widget.onScan(_manualCodeController.text);
                          Navigator.pop(context);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text('Valider'),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        widget.onClose();
                        Navigator.pop(context);
                      },
                      child: Text('Annuler'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileScanner() {
    return _MobileQRScanner(
      onScan: widget.onScan,
      onClose: widget.onClose,
    );
  }
}

class _MobileQRScanner extends StatefulWidget {
  final Function(String) onScan;
  final VoidCallback onClose;

  const _MobileQRScanner({
    super.key,
    required this.onScan,
    required this.onClose,
  });

  @override
  __MobileQRScannerState createState() => __MobileQRScannerState();
}

class __MobileQRScannerState extends State<_MobileQRScanner> {
  MobileScannerController cameraController = MobileScannerController();
  bool _isScanning = true;
  bool _isProcessing = false;

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scanner QR Code'),
        centerTitle: true,
        backgroundColor: Colors.blue,
        actions: [
          IconButton(
            icon: Icon(Icons.flashlight_off),
            onPressed: () => cameraController.toggleTorch(),
          ),
          IconButton(
            icon: Icon(Icons.cameraswitch),
            onPressed: () => cameraController.switchCamera(),
          ),
          IconButton(
            icon: Icon(Icons.close),
            onPressed: () {
              widget.onClose();
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Scanner
          MobileScanner(
            controller: cameraController,
            onDetect: (capture) {
              if (!_isScanning || _isProcessing) return;
              
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                if (barcode.rawValue != null) {
                  _isScanning = false;
                  setState(() => _isProcessing = true);
                  widget.onScan(barcode.rawValue!);
                  break;
                }
              }
            },
          ),
          
          // Overlay avec cadre de scan
          _buildScanOverlay(),
          
          // Message d'instruction
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.all(16),
              margin: EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.qr_code_scanner, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Positionnez le QR code dans le cadre',
                    style: TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
          
          // Indicateur de chargement
          if (_isProcessing)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      'Traitement en cours...',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildScanOverlay() {
    return Container(
      color: Colors.transparent,
      child: Center(
        child: Container(
          width: 250,
          height: 250,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white, width: 2),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Stack(
            children: [
              Positioned(
                top: 0,
                left: 0,
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(color: Colors.blue, width: 4),
                      left: BorderSide(color: Colors.blue, width: 4),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(color: Colors.blue, width: 4),
                      right: BorderSide(color: Colors.blue, width: 4),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Colors.blue, width: 4),
                      left: BorderSide(color: Colors.blue, width: 4),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Colors.blue, width: 4),
                      right: BorderSide(color: Colors.blue, width: 4),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}