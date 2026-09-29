import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';
import '../../projects/domain/project.dart';
import '../../projects/services/project_service.dart';

/// Interactive Property Agent Virtual Staging & Regulatory Disclosure Screen.
/// Fulfills Milestone 6.3 & Blueprint Section 41.
class PropertyStagingScreen extends StatefulWidget {
  final String? listingId;
  final String? projectId;
  final String propertyTitle;
  final PropertyListingRecordModel? initialListing;

  const PropertyStagingScreen({
    super.key,
    this.listingId,
    this.projectId,
    this.propertyTitle = 'Property Virtual Staging',
    this.initialListing,
  });

  @override
  State<PropertyStagingScreen> createState() => _PropertyStagingScreenState();
}

class _PropertyStagingScreenState extends State<PropertyStagingScreen> {
  PropertyListingRecordModel? _listing;
  bool _isLoading = true;
  int _selectedRoomIndex = 0;
  double _splitPosition = 0.5; // 0.0 = all original, 1.0 = all staged
  StagingType _selectedStagingMode = StagingType.virtualStagingEmpty;

  @override
  void initState() {
    super.initState();
    if (widget.initialListing != null) {
      _listing = widget.initialListing;
      _isLoading = false;
    } else {
      _loadListingData();
    }
  }

  Future<void> _loadListingData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      if (widget.listingId != null) {
        final listing = await ProjectService.fetchPropertyListingById(widget.listingId!);
        setState(() {
          _listing = listing;
          _isLoading = false;
        });
      } else {
        final listings = await ProjectService.fetchPropertyListings();
        if (listings.isNotEmpty) {
          setState(() {
            _listing = listings.first;
            _isLoading = false;
          });
        } else {
          // Fallback mock listing for offline / preview
          setState(() {
            _listing = _buildFallbackListing();
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      setState(() {
        _listing = _buildFallbackListing();
        _isLoading = false;
      });
    }
  }

  PropertyListingRecordModel _buildFallbackListing() {
    final disclosure = VirtualStagingDisclosureModel(
      isVirtuallyStaged: true,
      watermarkApplied: true,
      watermarkText: 'VIRTUALLY STAGED — FOR ILLUSTRATIVE PURPOSES ONLY',
      watermarkPosition: 'BOTTOM_RIGHT',
      disclosureStatement:
          'Virtually Staged: Furnishings and decor are digitally added for illustrative purposes only. Original room dimensions, walls, and permanent fixtures remain unaltered.',
      regulatoryFramework: 'RESO Standard / BOVAEP / CEA Guidelines',
      agentLicenseNo: 'REN 19482',
      agencyName: 'PropNex Realty Malaysia',
      originalImageUrl: 'https://images.unsplash.com/photo-1513694203232-719a280e022f',
      stagedImageUrl: 'https://images.unsplash.com/photo-1600585154340-be6161a56a0c',
    );

    final stagedAsset = StagedRoomAssetModel(
      assetId: 'stage_fallback_01',
      roomId: 'room_demo_living',
      roomName: 'Grand Living & Dining Room',
      stagingType: StagingType.virtualStagingEmpty,
      styleTheme: 'Warm Contemporary',
      originalImageUrl: 'https://images.unsplash.com/photo-1513694203232-719a280e022f',
      stagedImageUrl: 'https://images.unsplash.com/photo-1600585154340-be6161a56a0c',
      watermarkedImageUrl: 'https://images.unsplash.com/photo-1600585154340-be6161a56a0c',
      disclosure: disclosure,
    );

    return PropertyListingRecordModel(
      listingId: 'list_bangsar_01',
      propertyTitle: 'The Pavilion Suites, Bangsar',
      mlsNumber: 'MLS-MY-88291',
      propertyType: 'Condominium',
      bedrooms: 3,
      bathrooms: 3,
      builtUpSqft: 1450.0,
      listingPrice: 1850000.0,
      currency: 'MYR',
      propertyAddress: 'Level 18, 55 Jalan Telawi, Bangsar, 59100 Kuala Lumpur',
      listingAgentName: 'Sarah Wong',
      agentLicenseNo: 'REN 19482',
      agencyName: 'PropNex Realty Malaysia',
      agentPhone: '+60 12 889 1234',
      agentEmail: 'sarah.wong@propnex.my',
      stagedRooms: [stagedAsset],
    );
  }

  Future<void> _handleStageNewRoom() async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final titleController = TextEditingController(text: 'Primary Bedroom');
    String theme = 'Warm Contemporary';
    StagingType mode = _selectedStagingMode;

    final shouldStage = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.surface,
          title: const Text('Virtual Stage Room', style: TextStyle(color: AppTheme.textMain)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Room Name', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                const SizedBox(height: 4),
                TextField(
                  controller: titleController,
                  style: const TextStyle(color: AppTheme.textMain),
                  decoration: const InputDecoration(
                    hintText: 'e.g. Living Hall, Master Bedroom',
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Staging Workflow', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                const SizedBox(height: 6),
                DropdownButtonFormField<StagingType>(
                  initialValue: mode,
                  dropdownColor: AppTheme.surface,
                  style: const TextStyle(color: AppTheme.textMain),
                  items: StagingType.values.map((t) {
                    return DropdownMenuItem(value: t, child: Text(t.label));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() => mode = val);
                    }
                  },
                ),
                const SizedBox(height: 16),
                const Text('Style Theme', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: theme,
                  dropdownColor: AppTheme.surface,
                  style: const TextStyle(color: AppTheme.textMain),
                  items: const [
                    DropdownMenuItem(value: 'Warm Contemporary', child: Text('Warm Contemporary')),
                    DropdownMenuItem(value: 'Japandi Minimalist', child: Text('Japandi Minimalist')),
                    DropdownMenuItem(value: 'Scandinavian Light', child: Text('Scandinavian Light')),
                    DropdownMenuItem(value: 'Modern European', child: Text('Modern European')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() => theme = val);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Generate Concept'),
            ),
          ],
        ),
      ),
    );

    if (shouldStage == true && _listing != null) {
      try {
        final newAsset = await ProjectService.stageRoomForListing(
          _listing!.listingId,
          {
            'room_name': titleController.text.trim(),
            'staging_type': mode.code,
            'style_theme': theme,
            'floor_area_sqm': 24.0,
          },
        );

        setState(() {
          _listing!.stagedRooms.add(newAsset);
          _selectedRoomIndex = _listing!.stagedRooms.length - 1;
          _selectedStagingMode = newAsset.stagingType;
        });

        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('Room staged with regulatory disclosure watermark applied.'),
            backgroundColor: AppTheme.success,
          ),
        );
      } catch (e) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Staging failed: $e'),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    }
  }

  void _showDisclosureModal(VirtualStagingDisclosureModel disclosure) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.verified_outlined, color: AppTheme.accent, size: 24),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Regulatory Disclosure Controls',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textMain,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppTheme.textMuted),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(color: AppTheme.surfaceBorder, height: 24),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.surfaceBorder),
                ),
                child: Text(
                  disclosure.disclosureStatement,
                  style: const TextStyle(color: AppTheme.textMain, fontSize: 13, height: 1.4),
                ),
              ),
              const SizedBox(height: 16),
              _buildDisclosureDetailRow('Compliance Standard', disclosure.regulatoryFramework),
              _buildDisclosureDetailRow('Indelible Watermark', disclosure.watermarkApplied ? 'Applied' : 'Pending'),
              _buildDisclosureDetailRow('Watermark Badge', disclosure.watermarkText),
              _buildDisclosureDetailRow('Agent License', disclosure.agentLicenseNo ?? 'Registered Agent'),
              _buildDisclosureDetailRow('Agency', disclosure.agencyName ?? 'Partner Brokerage'),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.check),
                  label: const Text('Acknowledge Compliance'),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDisclosureDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
          Text(value, style: const TextStyle(color: AppTheme.textMain, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Future<void> _handleExportPortalBundle() async {
    if (_listing == null) return;
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      final bundle = await ProjectService.exportListingPortalBundle(
        _listing!.listingId,
        portalTarget: 'propertyguru',
      );

      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.surface,
          title: const Text('RESO Portal Export Bundle', style: TextStyle(color: AppTheme.textMain)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'MLS Syndication manifest generated with paired unedited baselines and legal disclosure attestation:',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.background,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.surfaceBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Listing ID: ${bundle.listingId}', style: const TextStyle(color: AppTheme.accent, fontSize: 12)),
                      Text('Format: ${bundle.portalFormat}', style: const TextStyle(color: AppTheme.textMain, fontSize: 12)),
                      Text('Staged Media Pairs: ${bundle.totalStagedRooms}', style: const TextStyle(color: AppTheme.textMain, fontSize: 12)),
                      const SizedBox(height: 8),
                      const Text('Attestation: MLS Compliant & Permanent Architecture Preserved', style: TextStyle(color: AppTheme.success, fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: bundle.toMap().toString()));
                scaffoldMessenger.showSnackBar(
                  const SnackBar(content: Text('RESO manifest copied to clipboard!')),
                );
                Navigator.pop(ctx);
              },
              child: const Text('Copy JSON Manifest', style: TextStyle(color: AppTheme.accent)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Export failed: $e'), backgroundColor: AppTheme.danger),
      );
    }
  }

  Future<void> _handleViewMarketingFlyer() async {
    if (_listing == null) return;
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      final html = await ProjectService.fetchPropertyMarketingFlyerHtml(_listing!.listingId);
      if (!mounted) return;

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppTheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) => Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Property Marketing Flyer', style: TextStyle(color: AppTheme.textMain, fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(Icons.close, color: AppTheme.textMuted), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 8),
              const Text('Print-ready HTML brochure with side-by-side original/staged photography and mandatory disclaimers.', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
              const SizedBox(height: 16),
              Container(
                height: 220,
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.surfaceBorder),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    html,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: AppTheme.textMuted),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.copy, size: 16),
                      label: const Text('Copy HTML'),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: html));
                        Navigator.pop(ctx);
                        scaffoldMessenger.showSnackBar(
                          const SnackBar(content: Text('Marketing flyer HTML copied to clipboard!')),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.share, size: 16),
                      label: const Text('Export PDF / Print'),
                      onPressed: () {
                        Navigator.pop(ctx);
                        scaffoldMessenger.showSnackBar(
                          const SnackBar(content: Text('Print preview triggered!')),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Flyer load failed: $e'), backgroundColor: AppTheme.danger),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppTheme.background,
        body: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
      );
    }

    final listing = _listing!;
    final stagedRooms = listing.stagedRooms;
    final currentRoom = stagedRooms.isNotEmpty && _selectedRoomIndex < stagedRooms.length
        ? stagedRooms[_selectedRoomIndex]
        : null;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(listing.propertyTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_upload_outlined),
            tooltip: 'Export Portal Bundle',
            onPressed: _handleExportPortalBundle,
          ),
          IconButton(
            icon: const Icon(Icons.print_outlined),
            tooltip: 'Marketing Flyer',
            onPressed: _handleViewMarketingFlyer,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Property Header & MLS Meta
            _buildListingHeaderCard(listing),

            // Staging Workflow Selector
            _buildStagingWorkflowBar(),

            // Before / After Comparison Area with Watermark & Disclosure
            if (currentRoom != null) ...[
              _buildRoomSelectorTabs(stagedRooms),
              _buildBeforeAfterInteractiveArea(currentRoom),
              if (currentRoom.renovationPotential != null)
                _buildRenovationPotentialCard(currentRoom.renovationPotential!),
            ] else ...[
              Padding(
                padding: const EdgeInsets.all(32.0),
                child: Center(
                  child: Column(
                    children: [
                      const Icon(Icons.chair_outlined, size: 48, color: AppTheme.textMuted),
                      const SizedBox(height: 12),
                      const Text(
                        'No rooms virtually staged for this listing yet.',
                        style: TextStyle(color: AppTheme.textMuted),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add_a_photo_outlined),
                        label: const Text('Stage First Room'),
                        onPressed: _handleStageNewRoom,
                      ),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 24),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.add_photo_alternate_outlined),
        label: const Text('Stage Room'),
        onPressed: _handleStageNewRoom,
      ),
    );
  }

  Widget _buildListingHeaderCard(PropertyListingRecordModel listing) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withAlpha(35),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  listing.mlsNumber ?? 'MLS LISTING',
                  style: const TextStyle(
                    color: AppTheme.accent,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                '${listing.currencySymbol} ${listing.listingPrice.toStringAsFixed(0)}',
                style: const TextStyle(
                  color: AppTheme.textMain,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            listing.propertyTitle,
            style: const TextStyle(
              color: AppTheme.textMain,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.location_on_outlined, color: AppTheme.textMuted, size: 14),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  listing.propertyAddress,
                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const Divider(color: AppTheme.surfaceBorder, height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${listing.bedrooms} Beds • ${listing.bathrooms} Baths • ${listing.builtUpSqft.toStringAsFixed(0)} sqft',
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
              ),
              Text(
                'Agent: ${listing.listingAgentName} (${listing.agentLicenseNo ?? "REN"})',
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStagingWorkflowBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'STAGING WORKFLOW OBJECTIVE',
            style: TextStyle(
              color: AppTheme.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.05,
            ),
          ),
          const SizedBox(height: 8),
          SegmentedButton<StagingType>(
            segments: const [
              ButtonSegment(
                value: StagingType.virtualStagingEmpty,
                label: Text('Empty Room', style: TextStyle(fontSize: 11)),
                icon: Icon(Icons.chair_outlined, size: 14),
              ),
              ButtonSegment(
                value: StagingType.declutterAndStage,
                label: Text('Declutter', style: TextStyle(fontSize: 11)),
                icon: Icon(Icons.cleaning_services_outlined, size: 14),
              ),
              ButtonSegment(
                value: StagingType.renovationPotential,
                label: Text('Renovate ROI', style: TextStyle(fontSize: 11)),
                icon: Icon(Icons.trending_up, size: 14),
              ),
            ],
            selected: {_selectedStagingMode},
            onSelectionChanged: (Set<StagingType> newSelection) {
              setState(() {
                _selectedStagingMode = newSelection.first;
              });
            },
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                if (states.contains(WidgetState.selected)) {
                  return AppTheme.primary;
                }
                return AppTheme.surface;
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomSelectorTabs(List<StagedRoomAssetModel> rooms) {
    return Container(
      height: 48,
      margin: const EdgeInsets.only(top: 16, bottom: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: rooms.length,
        itemBuilder: (context, index) {
          final isSelected = index == _selectedRoomIndex;
          final room = rooms[index];
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ChoiceChip(
              label: Text(room.roomName),
              selected: isSelected,
              selectedColor: AppTheme.accent.withAlpha(40),
              backgroundColor: AppTheme.surface,
              labelStyle: TextStyle(
                color: isSelected ? AppTheme.accent : AppTheme.textMuted,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
              ),
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _selectedRoomIndex = index;
                    _selectedStagingMode = room.stagingType;
                  });
                }
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildBeforeAfterInteractiveArea(StagedRoomAssetModel room) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.surfaceBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Visual Split Slider
          Stack(
            children: [
              // Background Image (Original Unfurnished / As-Is)
              SizedBox(
                height: 240,
                width: double.infinity,
                child: Image.network(
                  room.originalImageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: Colors.black26,
                    child: const Center(child: Text('Original Photo (Unfurnished)', style: TextStyle(color: AppTheme.textMuted))),
                  ),
                ),
              ),

              // Foreground Image (Virtually Staged Concept) clipped by split slider
              ClipRect(
                clipper: _HorizontalSplitClipper(revealRatio: _splitPosition),
                child: SizedBox(
                  height: 240,
                  width: double.infinity,
                  child: Image.network(
                    room.watermarkedImageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: Colors.black54,
                      child: const Center(child: Text('Virtually Staged Concept', style: TextStyle(color: AppTheme.accent))),
                    ),
                  ),
                ),
              ),

              // Indelible Watermark Badge (Mandatory Regulatory Disclosure)
              Positioned(
                bottom: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xDD0F172A),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.amber.withAlpha(120), width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        room.disclosure.watermarkText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.04,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Mode Tag Indicator
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xCC0F172A),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${room.stagingType.label} • ${room.styleTheme}',
                    style: const TextStyle(color: AppTheme.accent, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),

          // Interactive Split Slider Control
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text('Original As-Is', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                    Text('Virtually Staged', style: TextStyle(color: AppTheme.accent, fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
                Slider(
                  value: _splitPosition,
                  onChanged: (val) {
                    setState(() {
                      _splitPosition = val;
                    });
                  },
                  activeColor: AppTheme.accent,
                  inactiveColor: AppTheme.surfaceBorder,
                ),
              ],
            ),
          ),

          // Mandatory Disclosure Bar & Verification Pill
          InkWell(
            onTap: () => _showDisclosureModal(room.disclosure),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xFF0F172A),
                border: Border(top: BorderSide(color: AppTheme.surfaceBorder)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.verified_user_outlined, color: AppTheme.success, size: 18),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'RESO / BOVAEP / CEA Disclosure Compliant (Walls & Architecture Intact)',
                      style: TextStyle(color: AppTheme.textMain, fontSize: 11, fontWeight: FontWeight.w500),
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios, color: AppTheme.textMuted, size: 12),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRenovationPotentialCard(RenovationPotentialEstimateModel rp) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF064E3B).withAlpha(40),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF059669).withAlpha(100)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_graph, color: AppTheme.success, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Renovation Potential ROI Valuation',
                style: TextStyle(color: AppTheme.success, fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Est. Makeover Cost', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                  const SizedBox(height: 2),
                  Text(
                    '${rp.currencySymbol} ${rp.estimatedRenovationCost.toStringAsFixed(2)}',
                    style: const TextStyle(color: AppTheme.textMain, fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Projected Resale Uplift', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                  const SizedBox(height: 2),
                  Text(
                    '+${rp.currencySymbol} ${rp.estimatedValueUpliftAmount.toStringAsFixed(2)} (+${rp.indicativeValueUpliftPct}%)',
                    style: const TextStyle(color: AppTheme.success, fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text('Cosmetic Scope Items:', style: TextStyle(color: AppTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          ...rp.cosmeticScopeItems.map((item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline, size: 12, color: AppTheme.success),
                    const SizedBox(width: 6),
                    Expanded(child: Text(item, style: const TextStyle(color: AppTheme.textMain, fontSize: 12))),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

class _HorizontalSplitClipper extends CustomClipper<Rect> {
  final double revealRatio;

  _HorizontalSplitClipper({required this.revealRatio});

  @override
  Rect getClip(Size size) {
    return Rect.fromLTRB(0, 0, size.width * revealRatio, size.height);
  }

  @override
  bool shouldReclip(_HorizontalSplitClipper oldClipper) {
    return oldClipper.revealRatio != revealRatio;
  }
}
