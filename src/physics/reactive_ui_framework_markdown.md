# Reactive UI Framework - Complex Example

## Import Statements
import { createComponent, createReactiveState, onMount, onUpdate, onUnmount, watch, computed } from 'reactive-framework';

## Application Root
<app-root>
  <header>
    <h1>{{ title }}</h1>
    <nav>
      <ul>
        <li v-for="item in menuItems" :key="item.id" :class="{ active: item.active }" @click="selectMenu(item)">
          {{ item.label }}
        </li>
      </ul>
    </nav>
  </header>
  <main>
    <section v-if="showDashboard">
      <dashboard :data="dashboardData" :loading="isLoading" @refresh="fetchDashboard" />
    </section>
    <section v-else-if="showSettings">
      <settings-panel :settings="settings" @update="updateSettings" />
    </section>
    <section v-else>
      <p>Welcome to the reactive UI framework demo.</p>
    </section>
    <widget-container :widgets="widgets" @add-widget="addWidget" @remove-widget="removeWidget" />
  </main>
  <footer>
    <counter-display :count="clickCount" />
    <button @click="incrementCounter">Click me</button>
  </footer>
</app-root>

## Reactive State Definitions
const title = createReactiveState('Reactive UI Framework Demo');
const menuItems = createReactiveState([
  { id: 1, label: 'Dashboard', active: true },
  { id: 2, label: 'Settings', active: false },
  { id: 3, label: 'Profile', active: false },
]);
const showDashboard = createReactiveState(true);
const showSettings = createReactiveState(false);
const dashboardData = createReactiveState(null);
const isLoading = createReactiveState(false);
const settings = createReactiveState({
  theme: 'light',
  notifications: true,
  autoSave: false,
});
const widgets = createReactiveState([
  { id: 'widget1', type: 'chart', data: [] },
  { id: 'widget2', type: 'list', data: [] },
]);
const clickCount = createReactiveState(0);

## Functions for Menu Interaction
function selectMenu(item) {
  menuItems.value.forEach((i) => {
    i.active = i.id === item.id;
  });
  showDashboard.value = item.label === 'Dashboard';
  showSettings.value = item.label === 'Settings';
}

function fetchDashboard() {
  isLoading.value = true;
  fakeApiCall('/dashboard/data').then((data) => {
    dashboardData.value = data;
    isLoading.value = false;
  });
}

function updateSettings(newSettings) {
  Object.assign(settings.value, newSettings);
}

function addWidget(widgetType) {
  const newWidgetId = `widget${widgets.value.length + 1}`;
  const newWidget = { id: newWidgetId, type: widgetType, data: [] };
  widgets.value.push(newWidget);
}

function removeWidget(widgetId) {
  widgets.value = widgets.value.filter(w => w.id !== widgetId);
}

function incrementCounter() {
  clickCount.value += 1;
}

## Computed Properties
const isDarkTheme = computed(() => settings.value.theme === 'dark');
const activeMenuItem = computed(() => menuItems.value.find(item => item.active));
const widgetCount = computed(() => widgets.value.length);

## Lifecycle Hooks
onMount(() => {
  fetchDashboard();
});

onUpdate(() => {
  console.log('State updated:', {
    title: title.value,
    activeMenuItem: activeMenuItem.value,
    widgetCount: widgetCount.value,
  });
});

onUnmount(() => {
  console.log('Component unmounted');
});

## Watchers
watch(settings, (newSettings, oldSettings) => {
  if (newSettings.theme !== oldSettings.theme) {
    applyTheme(newSettings.theme);
  }
});

watch(clickCount, (newCount) => {
  if (newCount >= 10) {
    alert('You have clicked 10 times!');
  }
});

## Helper Functions
function fakeApiCall(endpoint) {
  return new Promise((resolve) => {
    setTimeout(() => {
      resolve({ message: 'Data loaded successfully', timestamp: Date.now() });
    }, 1000);
  });
}

function applyTheme(theme) {
  document.body.setAttribute('data-theme', theme);
}

function toggleNotifications() {
  settings.value.notifications = !settings.value.notifications;
}

## Child Component Definitions
createComponent('dashboard', {
  props: ['data', 'loading'],
  setup(props, { emit }) {
    const showDetails = createReactiveState(false);
    function toggleDetails() {
      showDetails.value = !showDetails.value;
    }
    return { showDetails, toggleDetails };
  },
  render() {
    if (this.loading) {
      return `<div class="loader">Loading...</div>`;
    }
    if (!this.data) {
      return `<div>No data available</div>`;
    }
    return `
      <div class="dashboard">
        <h2>Dashboard</h2>
        <button @click="toggleDetails">
          {{ showDetails ? 'Hide' : 'Show' }} Details
        </button>
        <div v-if="showDetails">
          <pre>{{ JSON.stringify(data, null, 2) }}</pre>
        </div>
        <button @click="$emit('refresh')">Refresh Data</button>
      </div>
    `;
  },
});

createComponent('settings-panel', {
  props: ['settings'],
  setup(props, { emit }) {
    const localSettings = createReactiveState({ ...props.settings });
    watch(props.settings, (newVal) => {
      Object.assign(localSettings.value, newVal);
    });
    function saveSettings() {
      emit('update', { ...localSettings.value });
    }
    return { localSettings, saveSettings };
  },
  render() {
    return `
      <div class="settings-panel">
        <h2>Settings</h2>
        <label>
          Theme:
          <select v-model="localSettings.theme">
            <option value="light">Light</option>
            <option value="dark">Dark</option>
          </select>
        </label>
        <label>
          Notifications:
          <input type="checkbox" v-model="localSettings.notifications" />
        </label>
        <label>
          Auto Save:
          <input type="checkbox" v-model="localSettings.autoSave" />
        </label>
        <button @click="saveSettings">Save</button>
      </div>
    `;
  },
});

createComponent('widget-container', {
  props: ['widgets'],
  setup(props, { emit }) {
    function handleAddWidget(type) {
      emit('add-widget', type);
    }
    function handleRemoveWidget(id) {
      emit('remove-widget', id);
    }
    return { handleAddWidget, handleRemoveWidget };
  },
  render() {
    return `
      <div class="widget-container">
        <h2>Widgets</h2>
        <div class="widget-list">
          <div v-for="widget in widgets" :key="widget.id" class="widget">
            <h3>{{ widget.type }} - {{ widget.id }}</h3>
            <button @click="handleRemoveWidget(widget.id)">Remove</button>
            <div v-if="widget.type === 'chart'">
              <chart-widget :data="widget.data" />
            </div>
            <div v-else-if="widget.type === 'list'">
              <list-widget :items="widget.data" />
            </div>
            <div v-else>
              <p>Unknown widget type</p>
            </div>
          </div>
        </div>
        <div class="add-widget-buttons">
          <button @click="handleAddWidget('chart')">Add Chart Widget</button>
          <button @click="handleAddWidget('list')">Add List Widget</button>
        </div>
      </div>
    `;
  },
});

createComponent('chart-widget', {
  props: ['data'],
  setup(props) {
    const chartData = computed(() => {
      if (!props.data.length) {
        return [0, 1, 2, 3, 4, 5];
      }
      return props.data;
    });
    return { chartData };
  },
  render() {
    return `
      <div class="chart-widget">
        <canvas></canvas>
        <script>
          const ctx = this.$el.querySelector('canvas').getContext('2d');
          new Chart(ctx, {
            type: 'line',
            data: {
              labels: this.chartData.map((_, i) => i + 1),
              datasets: [{
                label: 'Sample Data',
                data: this.chartData,
                borderColor: 'blue',
                fill: false,
              }],
            },
            options: {
              responsive: true,
              maintainAspectRatio: false,
            },
          });
        </script>
      </div>
    `;
  },
});

createComponent('list-widget', {
  props: ['items'],
  setup(props) {
    const sortedItems = computed(() => [...props.items].sort());
    return { sortedItems };
  },
  render() {
    return `
      <div class="list-widget">
        <ul>
          <li v-for="item in sortedItems" :key="item">{{ item }}</li>
        </ul