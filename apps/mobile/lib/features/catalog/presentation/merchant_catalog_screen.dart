import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../projects/domain/project.dart';
import '../../projects/services/project_service.dart';

/// Screen for browsing partner furniture merchants, inspecting seller storefronts,
/// validating spatial fit with confidence constraints, placing 3D items in rooms,
/// and tracking commercial click-out attribution.
/// Fulfills Milestone 6.1 & Blueprint Section 35.
class MerchantCatalogScreen extends StatefulWidget {
  final String? roomId;
  final String? roomName;
  final String? projectId;
  final String? designerId;

  const MerchantCatalogScreen({
    super.key,
    this.roomId,
    this.roomName,
    this.projectId,
    this.designerId,
  });

  @override
  State<MerchantCatalogScreen> createState() => _MerchantCatalogScreenState();
}

class _MerchantCatalogScreenState extends State<MerchantCatalogScreen> {
  bool _isLoading = true;
  List<MerchantModel> _merchants = [];
  String _selectedCountryFilter = 'ALL';
  MerchantModel? _activeMerchant;
  List<CatalogProductModel> _merchantProducts = [];
  bool _isLoadingProducts = false;
  CommerceAttributionSummaryModel? _attributionSummary;

  final List<String> _countryOptions = ['ALL', 'MY', 'SG', 'US', 'SE', 'DK'];

  @override
  void initState() {
    super.initState();
    _loadMerchants();
    _loadAttribution();
  }

  Future<void> _loadMerchants() async {
    setState(() => _isLoading = true);
    try {
      final country = _selectedCountryFilter == 'ALL' ? null : _selectedCountryFilter;
      final merchants = await ProjectService.fetchMerchants(country: country);
      setState(() {
        _merchants = merchants;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load sellers: $e')),
        );
      }
    }
  }

  Future<void> _loadAttribution() async {
    try {
      final summary = await ProjectService.fetchCommerceAttribution(
        projectId: widget.projectId,
      );
      if (mounted) {
        setState(() => _attributionSummary = summary);
      }
    } catch (_) {}
  }

  Future<void> _selectMerchant(MerchantModel merchant) async {
    setState(() {
      _activeMerchant = merchant;
      _isLoadingProducts = true;
    });

    try {
      final prods = await ProjectService.fetchMerchantProducts(merchant.merchantId);
      setState(() {
        _merchantProducts = prods;
        _isLoadingProducts = false;
      });
    } catch (e) {
      setState(() => _isLoadingProducts = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load merchant products: $e')),
        );
      }
    }
  }

  void _showOnboardMerchantDialog() {
    final messenger = ScaffoldMessenger.of(context);
    final nameCtrl = TextEditingController();
    final slugCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final siteCtrl = TextEditingController();
    String country = 'MY';
    double commission = 8.5;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.storefront, color: AppTheme.primary),
              SizedBox(width: 8),
              Text('Onboard Furniture Seller'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Business Name *',
                    hintText: 'e.g., Castlery Singapore',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: slugCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Store Slug *',
                    hintText: 'e.g., castlery-sg',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Partner Email *',
                    hintText: 'partner@brand.com',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: siteCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Website URL',
                    hintText: 'https://...',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: country,
                  decoration: const InputDecoration(labelText: 'HQ Country'),
                  items: const [
                    DropdownMenuItem(value: 'MY', child: Text('Malaysia (MY)')),
                    DropdownMenuItem(value: 'SG', child: Text('Singapore (SG)')),
                    DropdownMenuItem(value: 'US', child: Text('United States (US)')),
                    DropdownMenuItem(value: 'SE', child: Text('Sweden (SE)')),
                    DropdownMenuItem(value: 'DK', child: Text('Denmark (DK)')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDlgState(() => country = val);
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text('Commission: ${commission.toStringAsFixed(1)}%'),
                    ),
                    Slider(
                      value: commission,
                      min: 3.0,
                      max: 20.0,
                      divisions: 34,
                      onChanged: (v) => setDlgState(() => commission = v),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.isEmpty || slugCtrl.text.isEmpty || emailCtrl.text.isEmpty) {
                  return;
                }
                Navigator.pop(ctx);
                try {
                  await ProjectService.createMerchant(
                    businessName: nameCtrl.text.trim(),
                    storeSlug: slugCtrl.text.trim().toLowerCase(),
                    contactEmail: emailCtrl.text.trim(),
                    phone: phoneCtrl.text.trim().isNotEmpty ? phoneCtrl.text.trim() : null,
                    website: siteCtrl.text.trim().isNotEmpty ? siteCtrl.text.trim() : null,
                    country: country,
                    commissionRatePct: commission,
                  );
                  _loadMerchants();
                  if (mounted) {
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Seller successfully onboarded!')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    messenger.showSnackBar(
                      SnackBar(content: Text('Onboarding failed: $e')),
                    );
                  }
                }
              },
              child: const Text('Onboard'),
            ),
          ],
        ),
      ),
    );
  }

  void _showOnboardProductDialog(MerchantModel merchant) {
    final messenger = ScaffoldMessenger.of(context);
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController(text: '1200');
    final wCtrl = TextEditingController(text: '1.8');
    final dCtrl = TextEditingController(text: '0.9');
    final hCtrl = TextEditingController(text: '0.75');
    final glbCtrl = TextEditingController(text: 'https://assets.roomlyst.com/models/sample.glb');
    String category = 'SOFA';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          title: Text('Add Item: ${merchant.businessName}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Product Name *'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: category,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: const [
                    DropdownMenuItem(value: 'SOFA', child: Text('Sofa')),
                    DropdownMenuItem(value: 'DINING_TABLE', child: Text('Dining Table')),
                    DropdownMenuItem(value: 'COFFEE_TABLE', child: Text('Coffee Table')),
                    DropdownMenuItem(value: 'BED', child: Text('Bed')),
                    DropdownMenuItem(value: 'ARMCHAIR', child: Text('Armchair')),
                    DropdownMenuItem(value: 'LIGHTING', child: Text('Lighting')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDlgState(() => category = val);
                  },
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: priceCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Price (USD) *'),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: wCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Width (m)'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: dCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Depth (m)'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: hCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Height (m)'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: glbCtrl,
                  decoration: const InputDecoration(
                    labelText: '3D Asset URL (.glb)',
                    hintText: 'https://...',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.isEmpty || priceCtrl.text.isEmpty) return;
                Navigator.pop(ctx);
                try {
                  final price = double.tryParse(priceCtrl.text) ?? 500.0;
                  final w = double.tryParse(wCtrl.text) ?? 1.0;
                  final d = double.tryParse(dCtrl.text) ?? 1.0;
                  final h = double.tryParse(hCtrl.text) ?? 1.0;

                  await ProjectService.onboardMerchantProduct(
                    merchantId: merchant.merchantId,
                    name: nameCtrl.text.trim(),
                    category: category,
                    dimensions: ProductDimensionsModel(widthM: w, depthM: d, heightM: h),
                    price: price,
                    model3dUrl: glbCtrl.text.trim().isNotEmpty ? glbCtrl.text.trim() : null,
                  );
                  _selectMerchant(merchant);
                  if (mounted) {
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Item added to seller catalogue!')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    messenger.showSnackBar(
                      SnackBar(content: Text('Failed to add product: $e')),
                    );
                  }
                }
              },
              child: const Text('Save Product'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _verifyProductFit(CatalogProductModel product) async {
    if (widget.roomId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select or review a room to run fit verification.')),
      );
      return;
    }

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      final verification = await ProjectService.verifySellerProductFit(
        productId: product.id,
        roomId: widget.roomId!,
      );

      if (mounted) Navigator.pop(context); // Dismiss loading

      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Row(
              children: [
                Icon(
                  verification.isSafeToPurchase ? Icons.verified : Icons.warning_amber_rounded,
                  color: verification.isSafeToPurchase ? Colors.green : Colors.amber.shade800,
                ),
                const SizedBox(width: 8),
                const Text('Spatial Fit Assessment'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  'Room: ${widget.roomName ?? widget.roomId}',
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
                const Divider(height: 20),
                if (!verification.isFitClaimPermitted) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.shade300),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.shield_outlined, color: Colors.amber.shade900, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'CONFIDENCE NOTICE (Section 35):\nRoom measurement confidence is ${(verification.measurementConfidence * 100).toStringAsFixed(0)}% (threshold: 85%). Physical field measurement is strictly required before purchasing.',
                            style: TextStyle(color: Colors.amber.shade900, fontSize: 12, height: 1.3),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    verification.doorwayIngressCheck ? Icons.door_front_door : Icons.sensor_door_outlined,
                    color: verification.doorwayIngressCheck ? Colors.green : Colors.red,
                  ),
                  title: const Text('Doorway Ingress Clearance'),
                  subtitle: Text(
                    verification.doorwayIngressCheck
                        ? 'Passes entrance with +${verification.doorwayClearanceMarginM.toStringAsFixed(2)}m margin'
                        : 'Blocked! Entrance clearance deficit: ${verification.doorwayClearanceMarginM.toStringAsFixed(2)}m',
                  ),
                ),
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.straighten, color: AppTheme.primary),
                  title: const Text('Destination Floor Clearance'),
                  subtitle: Text('+${verification.destinationClearanceM.toStringAsFixed(2)}m spatial margin'),
                ),
                const SizedBox(height: 8),
                Text(
                  verification.notes,
                  style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.black87),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close'),
              ),
              if (verification.doorwayIngressCheck)
                ElevatedButton.icon(
                  icon: const Icon(Icons.add_location_alt_outlined, size: 16),
                  label: const Text('Place in Room'),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _showPlaceInRoomSheet(product);
                  },
                ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fit verification failed: $e')),
        );
      }
    }
  }

  void _showPlaceInRoomSheet(CatalogProductModel product) {
    if (widget.roomId == null) return;
    final messenger = ScaffoldMessenger.of(context);
    double posX = 0.5;
    double posY = 0.5;
    double rotDeg = 0.0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.view_in_ar, color: AppTheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Place: ${product.name}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text('Room Target: ${widget.roomName ?? widget.roomId}'),
              const SizedBox(height: 12),
              Text('X Position: ${(posX * 100).toStringAsFixed(0)}% across floor'),
              Slider(
                value: posX,
                min: 0.1,
                max: 0.9,
                onChanged: (v) => setSheetState(() => posX = v),
              ),
              Text('Y Position: ${(posY * 100).toStringAsFixed(0)}% depth'),
              Slider(
                value: posY,
                min: 0.1,
                max: 0.9,
                onChanged: (v) => setSheetState(() => posY = v),
              ),
              Text('Rotation: ${rotDeg.toStringAsFixed(0)}°'),
              Slider(
                value: rotDeg,
                min: 0.0,
                max: 360.0,
                divisions: 36,
                onChanged: (v) => setSheetState(() => rotDeg = v),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.check),
                  label: const Text('Confirm In-Room Placement'),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    try {
                      await ProjectService.addProductPlacement(
                        roomId: widget.roomId!,
                        productId: product.id,
                        positionX: posX,
                        positionY: posY,
                        rotationDeg: rotDeg,
                        boundingBox: product.dimensions,
                        model3dUrl: product.model3dUrl,
                        overlayImageUrl: product.imageUrl,
                      );
                      if (mounted) {
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text('${product.name} placed in ${widget.roomName ?? "room"}!'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        messenger.showSnackBar(
                          SnackBar(content: Text('Placement failed: $e')),
                        );
                      }
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleBuyClick(CatalogProductModel product) async {
    try {
      final url = product.retailerUrl ?? 'https://roomlyst.com/shop';
      final event = await ProjectService.trackCommerceClick(
        productId: product.id,
        productName: product.name,
        retailerUrl: url,
        merchantId: product.sellerId ?? _activeMerchant?.merchantId,
        projectId: widget.projectId,
        designerId: widget.designerId,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Attribution Token Created: ${event.affiliateToken}\nRedirecting to retailer...',
            ),
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'View',
              onPressed: () {},
            ),
          ),
        );
      }
      _loadAttribution();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to track commerce link: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Furniture Sellers & Catalogue'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_business),
            tooltip: 'Onboard Merchant',
            onPressed: _showOnboardMerchantDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_attributionSummary != null) _buildAttributionBanner(),
          _buildCountryFilterBar(),
          Expanded(
            child: _activeMerchant == null ? _buildMerchantList() : _buildStorefrontView(),
          ),
        ],
      ),
    );
  }

  Widget _buildAttributionBanner() {
    final summary = _attributionSummary!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppTheme.primary.withAlpha(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.insights, size: 16, color: AppTheme.primary),
              const SizedBox(width: 6),
              Text(
                'Affiliate GMV: ${summary.formattedInfluencedGmv}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primary),
              ),
            ],
          ),
          Text(
            'Clicks: ${summary.totalClicks} | Leads: ${summary.totalLeads}',
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _buildCountryFilterBar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: _countryOptions.map((c) {
          final isSelected = _selectedCountryFilter == c;
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(
              label: Text(c == 'ALL' ? 'All Regions' : c),
              selected: isSelected,
              onSelected: (val) {
                if (val) {
                  setState(() => _selectedCountryFilter = c);
                  _loadMerchants();
                }
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMerchantList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_merchants.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.storefront_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 12),
            const Text('No furniture merchants found in this region.'),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _showOnboardMerchantDialog,
              child: const Text('Onboard First Merchant'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _merchants.length,
      itemBuilder: (ctx, idx) {
        final m = _merchants[idx];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _selectMerchant(m),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: AppTheme.primary.withAlpha(30),
                    child: Text(
                      m.businessName.substring(0, 1).toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              m.businessName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            if (m.isVerified) ...[
                              const SizedBox(width: 4),
                              const Icon(Icons.verified, size: 16, color: Colors.blue),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${m.country} • ${m.activeListingCount} Listings • ${m.commissionRatePct}% Comm.',
                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStorefrontView() {
    final m = _activeMerchant!;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: Colors.grey.shade100,
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _activeMerchant = null),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      m.businessName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Text(
                      'Storefront • ${m.supportedCurrencies.join(', ')}',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Item'),
                onPressed: () => _showOnboardProductDialog(m),
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoadingProducts
              ? const Center(child: CircularProgressIndicator())
              : _merchantProducts.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.chair_outlined, size: 56, color: Colors.grey),
                          const SizedBox(height: 8),
                          Text('No active products for ${m.businessName}.'),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: () => _showOnboardProductDialog(m),
                            child: const Text('Upload Product Catalogue Item'),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _merchantProducts.length,
                      itemBuilder: (ctx, idx) => _buildProductCard(_merchantProducts[idx]),
                    ),
        ),
      ],
    );
  }

  Widget _buildProductCard(CatalogProductModel prod) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.chair, size: 36, color: Colors.grey),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              prod.name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                          ),
                          if (prod.model3dUrl != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.indigo.shade50,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '3D GLB',
                                style: TextStyle(color: Colors.indigo.shade800, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${prod.dimensions.widthM}m W × ${prod.dimensions.depthM}m D × ${prod.dimensions.heightM}m H',
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        prod.formattedPrice,
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.rule, size: 16),
                    label: const Text('Check Fit'),
                    onPressed: () => _verifyProductFit(prod),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.shopping_bag_outlined, size: 16),
                    label: const Text('Buy / Refer'),
                    onPressed: () => _handleBuyClick(prod),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
