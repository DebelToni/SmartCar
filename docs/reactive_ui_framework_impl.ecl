component ReactiveUIFramework {
    definition DataModel {
        property string id;
        property string name;
        property int age;
        property list<string> tags;
        property bool isActive;
        property date lastUpdated;
    }

    component StateManager {
        state map<string, DataModel> dataStore;
        state list<string> selectedIds;
        state bool loading;
        state string filterText;

        on event fetchData {
            set loading to true;
            execute async {
                data = call ExternalAPI.getData();
                for each item in data {
                    update dataStore[item.id] with item;
                }
                set loading to false;
            }
        }

        on event selectItem with payload string itemId {
            if selectedIds contains itemId {
                remove itemId from selectedIds;
            } else {
                append itemId to selectedIds;
            }
        }

        on event updateFilter with payload string filter {
            set filterText to filter;
        }

        on event refreshData {
            trigger fetchData;
        }
    }

    component UIComponent {
        property string searchInput;
        property list<DataModel> filteredData;
        property list<DataModel> displayedData;
        property bool showDetails;
        property DataModel currentItem;

        on event componentDidMount {
            trigger StateManager.fetchData;
        }

        on event onSearchInputChange with payload string input {
            trigger StateManager.updateFilter with payload input;
        }

        on event onItemSelected with payload string itemId {
            trigger StateManager.selectItem with payload itemId;
        }

        on event onRefreshClicked {
            trigger StateManager.refreshData;
        }

        on state filterText change {
            filteredData = filter StateManager.dataStore.values where {
                it.name contains StateManager.filterText or
                it.tags contains StateManager.filterText
            };
        }

        on state dataStore change or selectedIds change {
            displayedData = filter StateManager.dataStore.values where {
                selectedIds contains it.id or
                filterText is empty or
                it.name contains filterText or
                it.tags contains filterText
            };
        }

        on event onRowClick with payload string itemId {
            currentItem = StateManager.dataStore[itemId];
            showDetails = true;
        }

        on event onCloseDetails {
            showDetails = false;
            currentItem = null;
        }

        layout MainLayout {
            header {
                input field for searchInput with placeholder "Search..."
                button "Refresh" on click trigger StateManager.refreshData
            }
            body {
                list {
                    for each item in displayedData {
                        row {
                            cell { item.name }
                            cell { item.age }
                            cell { item.tags.join(", ") }
                            cell {
                                button "Select" on click trigger onItemSelected with payload item.id
                                if selectedIds contains item.id {
                                    label "Selected"
                                }
                            }
                            event on row click trigger onRowClick with payload item.id
                        }
                    }
                }
                if loading {
                    overlay {
                        spinner
                    }
                }
            }
            footer {
                if showDetails {
                    modal {
                        header { currentItem.name }
                        body {
                            paragraph { "ID: " + currentItem.id }
                            paragraph { "Age: " + currentItem.age }
                            paragraph { "Tags: " + currentItem.tags.join(", ") }
                            paragraph { "Last Updated: " + currentItem.lastUpdated.toString() }
                            button "Close" on click trigger onCloseDetails
                        }
                    }
                }
            }
        }
    }

    component Application {
        instantiate DataModel;
        instantiate StateManager;
        instantiate UIComponent;

        on componentDidMount {
            trigger UIComponent.componentDidMount;
        }
    }
}