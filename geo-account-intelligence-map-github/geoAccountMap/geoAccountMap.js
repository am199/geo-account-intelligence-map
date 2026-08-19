import { LightningElement } from 'lwc';

import { loadScript, loadStyle } from 'lightning/platformResourceLoader';

import LEAFLET from '@salesforce/resourceUrl/leaflet';

import getFilterOptions from '@salesforce/apex/GeoAccountMapController.getFilterOptions';
import getMapData from '@salesforce/apex/GeoAccountMapController.getMapData';

export default class GeoAccountMap extends LightningElement {

    // ============================================================
    // LEAFLET
    // ============================================================

    leafletLoaded = false;

    map;
    markerLayer;

    // ============================================================
    // NEW: RADIUS VISUALIZATION LAYER
    // ============================================================

    radiusLayer;

    radiusCenterMarker;

    radiusCircle;

    // ============================================================
    // DATA
    // ============================================================

    accounts = [];

    // ============================================================
    // FILTER OPTIONS
    // ============================================================

    industryOptions = [
        {
            label: 'All Industries',
            value: ''
        }
    ];

    stageOptions = [
        {
            label: 'All Stages',
            value: ''
        }
    ];

    ownerOptions = [
        {
            label: 'All Owners',
            value: ''
        }
    ];

    // ============================================================
    // SELECTED FILTERS
    // ============================================================

    selectedIndustry = '';

    selectedStage = '';

    selectedOwner = '';

    radius = '';

    // ============================================================
    // UI STATE
    // ============================================================

    loading = false;

    errorMessage = '';

    accountCount = 0;

    openOpportunityCount = 0;

    pipeline = 0;

    // ============================================================
    // DEFAULT MAP CENTER
    // ============================================================

    defaultLatitude = 39.8283;

    defaultLongitude = -98.5795;

    defaultZoom = 4;

    // ============================================================
    // NEW: RADIUS CENTER
    //
    // Initially the radius center is the USA default.
    //
    // When the user clicks the map, these values are replaced
    // with the clicked latitude and longitude.
    // ============================================================

    radiusCenterLatitude = 39.8283;

    radiusCenterLongitude = -98.5795;

    radiusCenterSelected = false;

    // ============================================================
    // LIFECYCLE
    // ============================================================

    renderedCallback() {

        if (this.leafletLoaded) {
            return;
        }

        this.leafletLoaded = true;

        Promise.all([
            loadScript(
                this,
                LEAFLET + '/leaflet.js'
            ),

            loadStyle(
                this,
                LEAFLET + '/leaflet.css'
            )
        ])
            .then(() => {

                console.log(
                    'Leaflet loaded successfully'
                );

                this.initializeMap();

                this.loadFilterOptions();

                this.loadMapData();

            })
            .catch(error => {

                console.error(
                    'Leaflet loading error:',
                    error
                );

                this.leafletLoaded = false;

                this.errorMessage =
                    'Unable to load the map library. Please check the Leaflet static resource.';
            });
    }

    // ============================================================
    // MAP INITIALIZATION
    // ============================================================

    initializeMap() {

        if (this.map) {
            return;
        }

        const container =
            this.template.querySelector(
                '.map-container'
            );

        if (!container) {

            console.error(
                'Map container not found'
            );

            return;
        }

        this.map =
            window.L.map(
                container,
                {
                    center: [
                        this.defaultLatitude,
                        this.defaultLongitude
                    ],

                    zoom: this.defaultZoom,

                    zoomControl: true,

                    attributionControl: true
                }
            );

        // ========================================================
        // OPEN STREET MAP
        // ========================================================

        window.L.tileLayer(
            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            {
                maxZoom: 19,

                attribution:
                    '&copy; OpenStreetMap contributors'
            }
        ).addTo(this.map);

        // ========================================================
        // ACCOUNT MARKER LAYER
        // ========================================================

        this.markerLayer =
            window.L.layerGroup()
                .addTo(this.map);

        // ========================================================
        // NEW: RADIUS LAYER
        //
        // This is separate from account markers so that
        // clearing account markers never removes the radius.
        // ========================================================

        this.radiusLayer =
            window.L.layerGroup()
                .addTo(this.map);

        // ========================================================
        // NEW: MAP CLICK
        //
        // Clicking anywhere on the map establishes the radius
        // center.
        // ========================================================

        this.map.on(
            'click',
            event => {

                this.handleMapClick(
                    event
                );

            }
        );

        // ========================================================
        // MAP SIZE FIX
        // ========================================================

        setTimeout(() => {

            if (this.map) {

                this.map.invalidateSize();

            }

        }, 300);

        console.log(
            'Map created successfully'
        );
    }

    // ============================================================
    // NEW: HANDLE MAP CLICK
    // ============================================================

    handleMapClick(event) {

        if (!event || !event.latlng) {
            return;
        }

        this.radiusCenterLatitude =
            event.latlng.lat;

        this.radiusCenterLongitude =
            event.latlng.lng;

        this.radiusCenterSelected = true;

        console.log(
            'Radius center selected:',
            this.radiusCenterLatitude,
            this.radiusCenterLongitude
        );

        // Immediately show the selected center
        // and current radius.
        this.updateRadiusVisualization();
    }

    // ============================================================
    // FILTER OPTIONS
    // ============================================================

    loadFilterOptions() {

        getFilterOptions()
            .then(result => {

                console.log(
                    'Filter options:',
                    result
                );

                this.industryOptions =
                    this.buildOptions(
                        result,
                        'industries',
                        'All Industries'
                    );

                this.stageOptions =
                    this.buildOptions(
                        result,
                        'stages',
                        'All Stages'
                    );

                this.ownerOptions =
                    this.buildOwnerOptions(
                        result
                    );

            })
            .catch(error => {

                console.error(
                    'Filter options error:',
                    error
                );

                this.errorMessage =
                    this.extractErrorMessage(
                        error
                    );
            });
    }

    // ============================================================
    // GENERIC OPTION BUILDER
    // ============================================================

    buildOptions(
        result,
        propertyName,
        allLabel
    ) {

        const source =
            result &&
            result[propertyName]
                ? result[propertyName]
                : [];

        const options = [
            {
                label: allLabel,
                value: ''
            }
        ];

        source.forEach(item => {

            if (
                item === null ||
                item === undefined
            ) {
                return;
            }

            if (
                typeof item === 'string'
            ) {

                if (
                    item.trim() !== ''
                ) {

                    options.push({
                        label: item,
                        value: item
                    });

                }

                return;
            }

            if (
                typeof item === 'object'
            ) {

                const label =
                    item.label ??
                    item.name ??
                    item.value ??
                    '';

                const value =
                    item.value ??
                    item.id ??
                    item.name ??
                    '';

                if (
                    label &&
                    value
                ) {

                    options.push({
                        label:
                            String(label),

                        value:
                            String(value)
                    });

                }
            }

        });

        return options;
    }

    // ============================================================
    // OWNER OPTION BUILDER
    // ============================================================

    buildOwnerOptions(result) {

        const source =
            result &&
            result.owners
                ? result.owners
                : [];

        const options = [
            {
                label: 'All Owners',
                value: ''
            }
        ];

        source.forEach(item => {

            if (
                item === null ||
                item === undefined
            ) {
                return;
            }

            if (
                typeof item === 'string'
            ) {

                if (
                    item.trim() !== ''
                ) {

                    options.push({
                        label: item,
                        value: item
                    });

                }

                return;
            }

            if (
                typeof item === 'object'
            ) {

                const label =
                    item.label ??
                    item.name ??
                    item.ownerName ??
                    item.Name ??
                    '';

                const value =
                    item.value ??
                    item.id ??
                    item.ownerId ??
                    item.Id ??
                    label;

                if (label) {

                    options.push({
                        label:
                            String(label),

                        value:
                            String(value)
                    });

                }
            }

        });

        return options;
    }

    // ============================================================
    // LOAD MAP DATA
    // ============================================================

    loadMapData() {

        if (!this.map) {
            return;
        }

        this.loading = true;

        this.errorMessage = '';

        const radiusValue =
            this.getRadiusValue();

        // ========================================================
        // RADIUS CENTER
        //
        // IMPORTANT:
        // Do NOT use this.map.getCenter().
        //
        // The Leaflet map can move because fitBounds() changes
        // the visual map center.
        //
        // We use our own stored radius center instead.
        // ========================================================

        const centerLatitude =
            this.radiusCenterLatitude;

        const centerLongitude =
            this.radiusCenterLongitude;

        console.log(
            '================ RADIUS REQUEST ================'
        );

        console.log(
            'Radius:',
            radiusValue
        );

        console.log(
            'Center:',
            centerLatitude,
            centerLongitude
        );

        console.log(
            'Center selected by user:',
            this.radiusCenterSelected
        );

        console.log(
            'Industry:',
            this.selectedIndustry
        );

        console.log(
            'Stage:',
            this.selectedStage
        );

        console.log(
            'Owner:',
            this.selectedOwner
        );

        console.log(
            '================================================='
        );

        // ========================================================
        // CALL APEX
        // ========================================================

        getMapData({

            industry:
                this.selectedIndustry ||
                null,

            opportunityStage:
                this.selectedStage ||
                null,

            opportunityOwnerId:
                this.selectedOwner ||
                null,

            radiusMiles:
                radiusValue,

            centerLatitude:
                centerLatitude,

            centerLongitude:
                centerLongitude

        })
            .then(result => {

                console.log(
                    'Accounts returned from Apex:',
                    result
                );

                this.accounts =
                    Array.isArray(result)
                        ? result
                        : [];

                console.log(
                    'Account count:',
                    this.accounts.length
                );

                this.updateSummary();

                this.renderMarkers();

            })
            .catch(error => {

                console.error(
                    'Map data error:',
                    error
                );

                this.accounts = [];

                this.updateSummary();

                this.clearMarkers();

                this.errorMessage =
                    this.extractErrorMessage(
                        error
                    );
            })
            .finally(() => {

                this.loading = false;

                setTimeout(() => {

                    if (this.map) {

                        this.map.invalidateSize();

                    }

                }, 100);
            });
    }

    // ============================================================
    // RADIUS VALUE
    // ============================================================

    getRadiusValue() {

        if (
            this.radius === null ||
            this.radius === undefined ||
            this.radius === ''
        ) {

            return null;
        }

        const numericRadius =
            Number(this.radius);

        if (
            Number.isNaN(
                numericRadius
            ) ||
            numericRadius <= 0
        ) {

            return null;
        }

        return numericRadius;
    }

    // ============================================================
    // FILTER HANDLERS
    // ============================================================

    handleIndustryChange(event) {

        this.selectedIndustry =
            event.target.value || '';
    }

    handleStageChange(event) {

        this.selectedStage =
            event.target.value || '';
    }

    handleOwnerChange(event) {

        this.selectedOwner =
            event.target.value || '';
    }

    // ============================================================
    // RADIUS CHANGE
    // ============================================================

    handleRadiusChange(event) {

        this.radius =
            event.target.value;

        // Update the visual circle immediately.
        //
        // This does NOT call Apex.
        // Apex is called only when Apply Filters is clicked.

        this.updateRadiusVisualization();
    }

    // ============================================================
    // APPLY FILTERS
    // ============================================================

    handleApplyFilters() {

        this.errorMessage = '';

        this.loadMapData();
    }

    // ============================================================
    // RESET
    // ============================================================

    handleReset() {

        this.selectedIndustry = '';

        this.selectedStage = '';

        this.selectedOwner = '';

        this.radius = '';

        this.errorMessage = '';

        // ========================================================
        // RESET RADIUS CENTER
        // ========================================================

        this.radiusCenterLatitude =
            this.defaultLatitude;

        this.radiusCenterLongitude =
            this.defaultLongitude;

        this.radiusCenterSelected =
            false;

        this.clearRadiusVisualization();

        this.loadMapData();

        setTimeout(() => {

            if (this.map) {

                this.map.setView(
                    [
                        this.defaultLatitude,
                        this.defaultLongitude
                    ],
                    this.defaultZoom
                );

            }

        }, 200);
    }

    // ============================================================
    // NEW: UPDATE RADIUS VISUALIZATION
    // ============================================================

    updateRadiusVisualization() {

        if (
            !this.map ||
            !this.radiusLayer
        ) {

            return;
        }

        // Always remove the previous visualization first.
        this.radiusLayer.clearLayers();

        this.radiusCircle = null;

        this.radiusCenterMarker = null;

        const latitude =
            this.radiusCenterLatitude;

        const longitude =
            this.radiusCenterLongitude;

        // ========================================================
        // CENTER MARKER
        //
        // Only show it after the user has clicked the map.
        // ========================================================

        if (
            this.radiusCenterSelected
        ) {

            this.radiusCenterMarker =
                window.L.circleMarker(
                    [
                        latitude,
                        longitude
                    ],
                    {
                        radius: 7,

                        color: '#ffffff',

                        weight: 2,

                        fillColor: '#7c5cff',

                        fillOpacity: 1
                    }
                );

            this.radiusCenterMarker
                .bindPopup(
                    `
                    <div style="
                        font-family:Arial,sans-serif;
                        min-width:180px;
                    ">
                        <div style="
                            font-size:14px;
                            font-weight:700;
                            margin-bottom:6px;
                        ">
                            Radius Center
                        </div>

                        <div style="
                            font-size:11px;
                            color:#555;
                        ">
                            Latitude:
                            ${latitude.toFixed(5)}
                        </div>

                        <div style="
                            font-size:11px;
                            color:#555;
                        ">
                            Longitude:
                            ${longitude.toFixed(5)}
                        </div>
                    </div>
                    `
                );

            this.radiusCenterMarker
                .addTo(this.radiusLayer);
        }

        // ========================================================
        // RADIUS
        // ========================================================

        const radiusValue =
            this.getRadiusValue();

        // No radius = no circle.
        if (
            radiusValue === null
        ) {

            return;
        }

        // ========================================================
        // LEAFLET CIRCLE
        //
        // Leaflet expects meters.
        //
        // 1 mile = 1609.344 meters
        // ========================================================

        const radiusMeters =
            radiusValue * 1609.344;

        this.radiusCircle =
            window.L.circle(
                [
                    latitude,
                    longitude
                ],
                {
                    radius:
                        radiusMeters,

                    color: '#7c5cff',

                    weight: 2,

                    opacity: 0.9,

                    fillColor: '#7c5cff',

                    fillOpacity: 0.12
                }
            );

        this.radiusCircle
            .addTo(this.radiusLayer);

        // ========================================================
        // POPUP ON CIRCLE
        // ========================================================

        this.radiusCircle
            .bindPopup(
                `
                <div style="
                    font-family:Arial,sans-serif;
                    min-width:180px;
                ">
                    <div style="
                        font-size:14px;
                        font-weight:700;
                        margin-bottom:6px;
                    ">
                        Search Radius
                    </div>

                    <div style="
                        font-size:12px;
                        color:#555;
                    ">
                        ${radiusValue} miles
                    </div>
                </div>
                `
            );
    }

    // ============================================================
    // NEW: CLEAR RADIUS VISUALIZATION
    // ============================================================

    clearRadiusVisualization() {

        if (!this.radiusLayer) {
            return;
        }

        this.radiusLayer.clearLayers();

        this.radiusCircle = null;

        this.radiusCenterMarker = null;
    }

    // ============================================================
    // VALID ACCOUNT DATA
    // ============================================================

    getValidAccounts() {

        return this.accounts.filter(
            account => {

                const latitude =
                    Number(
                        account.latitude ??
                        account.Latitude
                    );

                const longitude =
                    Number(
                        account.longitude ??
                        account.Longitude
                    );

                return (
                    Number.isFinite(
                        latitude
                    ) &&

                    Number.isFinite(
                        longitude
                    ) &&

                    latitude >= -90 &&

                    latitude <= 90 &&

                    longitude >= -180 &&

                    longitude <= 180
                );
            }
        );
    }

    // ============================================================
    // RENDER MARKERS
    // ============================================================

    renderMarkers() {

        if (
            !this.map ||
            !this.markerLayer
        ) {

            return;
        }

        this.clearMarkers();

        const accounts =
            this.getValidAccounts();

        console.log(
            'Rendering markers:',
            accounts.length
        );

        if (
            accounts.length === 0
        ) {

            return;
        }

        accounts.forEach(
            account => {

                const latitude =
                    Number(
                        account.latitude ??
                        account.Latitude
                    );

                const longitude =
                    Number(
                        account.longitude ??
                        account.Longitude
                    );

                const signal =
                    this.getSignal(
                        account
                    );

                const marker =
                    window.L.circleMarker(
                        [
                            latitude,
                            longitude
                        ],
                        {
                            radius: 8,

                            color: '#ffffff',

                            weight: 2,

                            fillColor:
                                this.getSignalColor(
                                    signal
                                ),

                            fillOpacity: 1
                        }
                    );

                marker.bindPopup(
                    this.buildPopup(
                        account
                    )
                );

                marker.addTo(
                    this.markerLayer
                );
            }
        );

        // ========================================================
        // ONLY FIT BOUNDS WHEN RADIUS IS NOT ACTIVE
        // ========================================================

        const radiusValue =
            this.getRadiusValue();

        if (!radiusValue) {

            const bounds =
                window.L.latLngBounds(
                    []
                );

            accounts.forEach(
                account => {

                    bounds.extend(
                        [
                            Number(
                                account.latitude ??
                                account.Latitude
                            ),

                            Number(
                                account.longitude ??
                                account.Longitude
                            )
                        ]
                    );

                }
            );

            if (
                bounds.isValid()
            ) {

                this.map.fitBounds(
                    bounds,
                    {
                        padding: [
                            40,
                            40
                        ],

                        maxZoom: 5
                    }
                );
            }
        }

        // ========================================================
        // IMPORTANT
        //
        // Radius visualization must stay on top after markers
        // are rendered.
        // ========================================================

        if (
            this.radiusCenterSelected
        ) {

            this.updateRadiusVisualization();
        }
    }

    // ============================================================
    // CLEAR MARKERS
    // ============================================================

    clearMarkers() {

        if (
            this.markerLayer
        ) {

            this.markerLayer.clearLayers();
        }
    }

    // ============================================================
    // SIGNAL
    // ============================================================

    getSignal(account) {

        const signal =
            account.signal ??
            account.opportunitySignal ??
            account.Signal ??
            '';

        return String(
            signal
        ).toLowerCase();
    }

    getSignalColor(signal) {

        switch (signal) {

            case 'high':
                return '#2ecc71';

            case 'medium':
                return '#f5a623';

            case 'low':
                return '#a0a0a0';

            default:
                return '#3b82f6';
        }
    }

    // ============================================================
    // POPUP
    // ============================================================

    buildPopup(account) {

        const accountName =
            this.escapeHtml(
                account.accountName ??
                account.name ??
                account.Name ??
                'Unknown Account'
            );

        const city =
            this.escapeHtml(
                account.city ??
                account.City ??
                ''
            );

        const country =
            this.escapeHtml(
                account.country ??
                account.Country ??
                ''
            );

        const industry =
            this.escapeHtml(
                account.industry ??
                account.Industry ??
                '—'
            );

        const opportunities =
            account.openOpportunityCount ??
            account.openOpportunities ??
            account.opportunityCount ??
            0;

        const pipeline =
            Number(
                account.pipeline ??
                account.pipelineAmount ??
                0
            );

        const owner =
            this.escapeHtml(
                account.ownerName ??
                account.opportunityOwnerName ??
                account.owner ??
                '—'
            );

        const stage =
            this.escapeHtml(
                account.opportunityStage ??
                account.stageName ??
                account.stage ??
                '—'
            );

        const signal =
            this.getSignal(
                account
            );

        const signalColor =
            this.getSignalColor(
                signal
            );

        const location =
            [
                city,
                country
            ]
                .filter(Boolean)
                .join(', ');

        return `
            <div style="
                min-width:230px;
                font-family:Arial,sans-serif;
                color:#202124;
            ">

                <div style="
                    font-size:16px;
                    font-weight:700;
                    margin-bottom:10px;
                ">
                    ${accountName}
                </div>

                <div style="
                    margin-bottom:6px;
                ">
                    <b>Location:</b>
                    ${location || '—'}
                </div>

                <div style="
                    margin-bottom:6px;
                ">
                    <b>Industry:</b>
                    ${industry}
                </div>

                <div style="
                    margin-bottom:6px;
                ">
                    <b>Open Opportunities:</b>
                    ${opportunities}
                </div>

                <div style="
                    margin-bottom:6px;
                ">
                    <b>Pipeline:</b>
                    ${this.formatCurrency(
                        pipeline
                    )}
                </div>

                <div style="
                    margin-bottom:6px;
                ">
                    <b>Stage:</b>

                    <span style="
                        display:inline-block;
                        margin-left:5px;
                        padding:2px 7px;
                        border-radius:10px;
                        background:${signalColor};
                        color:#ffffff;
                        font-size:11px;
                        font-weight:700;
                    ">
                        ${stage}
                    </span>
                </div>

                <div>
                    <b>Owner:</b>
                    ${owner}
                </div>

            </div>
        `;
    }

    // ============================================================
    // SUMMARY
    // ============================================================

    updateSummary() {

        this.accountCount =
            this.accounts.length;

        this.openOpportunityCount =
            this.accounts.reduce(
                (
                    total,
                    account
                ) => {

                    return total +
                        Number(
                            account.openOpportunityCount ??
                            account.openOpportunities ??
                            account.opportunityCount ??
                            0
                        );
                },
                0
            );

        this.pipeline =
            this.accounts.reduce(
                (
                    total,
                    account
                ) => {

                    return total +
                        Number(
                            account.pipeline ??
                            account.pipelineAmount ??
                            0
                        );
                },
                0
            );
    }

    // ============================================================
    // FORMATTING
    // ============================================================

    get formattedPipeline() {

        return this.formatCurrency(
            this.pipeline
        );
    }

    formatCurrency(value) {

        const numericValue =
            Number(value) || 0;

        return new Intl.NumberFormat(
            'en-US',
            {
                style: 'currency',

                currency: 'USD',

                maximumFractionDigits: 2
            }
        ).format(
            numericValue
        );
    }

    // ============================================================
    // NO RESULTS
    // ============================================================

    get showNoResults() {

        return (
            !this.loading &&
            !this.errorMessage &&
            this.accounts.length === 0
        );
    }

    // ============================================================
    // ERROR HANDLING
    // ============================================================

    extractErrorMessage(error) {

        if (!error) {

            return 'Unknown error occurred.';
        }

        if (error.body) {

            if (
                Array.isArray(
                    error.body
                )
            ) {

                return error.body
                    .map(
                        item =>
                            item.message
                    )
                    .join(', ');
            }

            if (
                error.body.message
            ) {

                return error.body.message;
            }
        }

        if (error.message) {

            return error.message;
        }

        return 'Something went wrong while loading the map.';
    }

    // ============================================================
    // HTML ESCAPE
    // ============================================================

    escapeHtml(value) {

        return String(value)
            .replace(
                /&/g,
                '&amp;'
            )
            .replace(
                /</g,
                '&lt;'
            )
            .replace(
                />/g,
                '&gt;'
            )
            .replace(
                /"/g,
                '&quot;'
            )
            .replace(
                /'/g,
                '&#039;'
            );
    }
}