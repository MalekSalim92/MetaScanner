import { LightningElement, wire, track } from 'lwc';
import fetchMetadataItems from '@salesforce/apex/WhereUsedMetadataService.fetchMetadataItems';
import getDependencies from '@salesforce/apex/WhereUsedMetadataService.getDependencies';
import getMetadataAccess from '@salesforce/apex/WhereUsedMetadataService.getMetadataAccess';

export default class WhereUsedLwc extends LightningElement {
    selectedMetadata = 'ApexClass';
    metadataItems = [];
    displayedItems = [];
    searchTerm = '';
    currentPage = 1;
    pageSize = 10;
    totalItems = 0;
    clickedId;
    dependencies = [];
    @track accessData = null;
    
    showDependenciesModal = false;
    showAccessModal = false;
    isLoadingDependencies = false;
    isLoadingAccess = false;

    metadataOptions = [
        { label: "Custom Object", value: "CustomObject", icon: "utility:open_folder" },
        { label: "Custom Field", value: "CustomField", icon: "utility:file" },
        { label: "Flow", value: "FlowDefinition", icon: "utility:flow" },
        { label: "Apex Class", value: "ApexClass", icon: "utility:apex" },
        { label: "Apex Trigger", value: "ApexTrigger", icon: "utility:connected_apps" },
        { label: "LWC", value: "LightningComponentBundle", icon: "utility:component_customization" }
    ];

    @wire(fetchMetadataItems, { metadataType: '$selectedMetadata' })
    wiredMetadataItems({ data, error }) {
        if (data) {
            this.metadataItems = data;
            this.totalItems = data.length;
            this.updateDisplayedItems();
        } else if (error) {
            console.error(error);
            this.metadataItems = [];
            this.displayedItems = [];
            this.totalItems = 0;
        }
    }

    handleSelectMetadata(event) {
        this.selectedMetadata = event.detail.name;
        this.searchTerm = '';
        this.currentPage = 1;
        this.dependencies = [];
        this.showDependenciesModal = false;
        this.showAccessModal = false;
    }

    handleClick(event) {
        this.clickedId = event.currentTarget.dataset.id;
        
        console.log('Row clicked, ID:', this.clickedId);
        
        if (!this.clickedId) return;
        
        this.openDependenciesModal();
    }

    async handleShowAccess(event) {
        event.stopPropagation();
        event.preventDefault();
        const clickedId = event.currentTarget.dataset.id;
    
        console.log('Access button clicked, ID:', clickedId);
        
        if (!clickedId) return;
    
        this.showAccessModal = true;
        this.isLoadingAccess = true;
        this.accessData = null;
        
        try {
            const result = await getMetadataAccess({ 
                metadataType: this.selectedMetadata, 
                metadataId: clickedId 
            });
    
            console.log('Access data received:', result);
            
            if (result && result.records) {
                // Add display symbols based on type
                const processedRecords = result.records.map(item => {
                    if (result.displayType === 'simple') {
                        return {
                            ...item,
                            accessSymbol: item.hasAccess ? '✅' : '❌'
                        };
                    } else {
                        return {
                            ...item,
                            readSymbol: item.permRead ? '✅' : '❌',
                            createSymbol: item.permCreate != null ? (item.permCreate ? '✅' : '❌') : '-',
                            editSymbol: item.permEdit ? '✅' : '❌',
                            deleteSymbol: item.permDelete != null ? (item.permDelete ? '✅' : '❌') : '-'
                        };
                    }
                });
                
                this.accessData = {
                    displayType: result.displayType,
                    records: processedRecords
                };
            }
        } catch (error) {
            console.error('Error fetching access table:', error);
            this.accessData = null;
        } finally {
            this.isLoadingAccess = false;
        }
    }

    async openDependenciesModal() {
        console.log('Opening dependencies modal for ID:', this.clickedId);
        console.log('showDependenciesModal BEFORE:', this.showDependenciesModal);
        
        this.isLoadingDependencies = true;
        this.showDependenciesModal = true;
        
        console.log('showDependenciesModal AFTER:', this.showDependenciesModal);
        
        this.dependencies = [];

        try {
            const metadataDependency = await getDependencies({ metadataType: this.selectedMetadata });
            console.log('Dependencies received:', metadataDependency);
            this.dependencies = metadataDependency.filter(dep => dep.refId === this.clickedId);
            console.log('Filtered dependencies:', this.dependencies);
        } catch (error) {
            console.error('Error fetching dependencies:', error);
            this.dependencies = [];
        } finally {
            this.isLoadingDependencies = false;
        }
    }

    closeDependenciesModal() {
        this.showDependenciesModal = false;
        this.dependencies = [];
    }

    closeAccessModal() {
        this.showAccessModal = false;
        this.accessData = null;
    }

    handleSearch(event) {
        this.searchTerm = event.target.value.toLowerCase();
        this.currentPage = 1;
        this.updateDisplayedItems();
    }

    updateDisplayedItems() {
        let filtered = this.metadataItems.filter(item =>
            item.developerName?.toLowerCase().includes(this.searchTerm)
        );
        const start = (this.currentPage - 1) * this.pageSize;
        const end = start + this.pageSize;
        this.displayedItems = filtered.slice(start, end);
    }

    handleNextPage() {
        const totalPages = Math.ceil(this.getFilteredItemsCount() / this.pageSize);
        if (this.currentPage < totalPages) this.currentPage++;
        this.updateDisplayedItems();
    }

    handlePrevPage() {
        if (this.currentPage > 1) this.currentPage--;
        this.updateDisplayedItems();
    }

    getFilteredItemsCount() {
        return this.searchTerm
            ? this.metadataItems.filter(item => item.developerName?.toLowerCase().includes(this.searchTerm)).length
            : this.metadataItems.length;
    }

    get totalPages() {
        return Math.ceil(this.getFilteredItemsCount() / this.pageSize);
    }

    get disablePrevious() {
        return this.currentPage === 1;
    }

    get disableNext() {
        return this.currentPage === this.totalPages;
    }

    get showPagination() {
        return this.totalPages > 1;
    }

    get showNoResults() {
        return this.metadataItems.length > 0 && this.displayedItems.length === 0 && this.searchTerm;
    }

    get showNoData() {
        return this.metadataItems.length === 0;
    }

    get hasNoDependencies() {
        return !this.isLoadingDependencies && this.dependencies.length === 0;
    }

    get hasNoAccess() {
        return !this.isLoadingAccess && (!this.accessData || this.accessData.records.length === 0);
    }

    get showSimpleAccess() {
        return this.accessData && this.accessData.displayType === 'simple';
    }

    get showCrudAccess() {
        return this.accessData && this.accessData.displayType === 'crud';
    }

    // Hide access button for inherited/contextual metadata types
    get showAccessButton() {
        return ['ApexClass', 'CustomObject', 'CustomField'].includes(this.selectedMetadata);
    }
}