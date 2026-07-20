<script setup>
import { ref, onMounted } from 'vue';
import Draggable from 'vuedraggable';
import pipelineApi from '../../../../api/pipelines';
import dealApi from '../../../../api/deals';
import DealCard from '../components/DealCard.vue';
import CreateDealModal from '../components/CreateDealModal.vue';

const pipelines = ref([]);
const activePipeline = ref(null);
const stages = ref([]);
const showCreateModal = ref(false);
const isLoading = ref(false);

const loadBoard = async () => {
  isLoading.value = true;
  try {
    const response = await pipelineApi.get();
    pipelines.value = response.data || [];
    if (pipelines.value.length > 0) {
      activePipeline.value = pipelines.value[0];
      stages.value = activePipeline.value.pipeline_stages || [];
      
      stages.value.forEach(stage => {
        if (stage.deals) {
          stage.deals.sort((a, b) => a.position - b.position);
        } else {
          stage.deals = [];
        }
      });
    }
  } catch (err) {
    console.error('Error loading board data:', err);
  } finally {
    isLoading.value = false;
  }
};

onMounted(() => {
  loadBoard();
});

const getStageTotalValue = stage => {
  if (!stage.deals || stage.deals.length === 0) return '$0.00';
  const total = stage.deals.reduce((sum, deal) => sum + parseFloat(deal.value || 0), 0);
  const formatter = new Intl.NumberFormat('es-CO', {
    style: 'currency',
    currency: stage.deals[0].currency || 'USD',
    minimumFractionDigits: 0,
  });
  return formatter.format(total);
};

const onDragChange = async (event, stageId) => {
  if (event.added) {
    const deal = event.added.element;
    const newIndex = event.added.newIndex;
    
    if (deal.is_virtual) {
      try {
        const payload = {
          name: deal.name,
          value: 0.0,
          currency: deal.currency || 'USD',
          pipeline_stage_id: stageId,
          contact_id: deal.contact_id,
        };
        const response = await dealApi.create(payload);
        
        const stage = stages.value.find(s => s.id === stageId);
        if (stage && stage.deals) {
          const idx = stage.deals.findIndex(d => d.id === deal.id);
          if (idx !== -1) {
            stage.deals[idx] = response.data;
          }
        }
      } catch (err) {
        console.error('Error converting virtual deal:', err);
      }
    } else {
      try {
        await dealApi.update(deal.id, {
          pipeline_stage_id: stageId,
          position: newIndex,
        });
      } catch (err) {
        console.error('Error updating deal position:', err);
      }
    }
  } else if (event.moved) {
    const deal = event.moved.element;
    const newIndex = event.moved.newIndex;
    try {
      await dealApi.update(deal.id, {
        pipeline_stage_id: stageId,
        position: newIndex,
      });
    } catch (err) {
      console.error('Error updating deal reorder:', err);
    }
  }
};

const onDealCreated = () => {
  loadBoard();
};

const onDealDeleted = () => {
  loadBoard();
};
</script>

<template>
  <div class="kanban-page">
    <header class="kanban-header">
      <div class="header-left">
        <h1 class="page-title">Embudo de Ventas</h1>
        <p class="page-subtitle">Gestiona tus prospectos, tratos y ventas en tiempo real.</p>
      </div>
      <button class="add-deal-btn" @click="showCreateModal = true">
        <span class="btn-icon">+</span> Nuevo Trato
      </button>
    </header>

    <div v-if="isLoading" class="loader-container">
      <span class="spinner"></span>
      <p class="loader-text">Cargando tu embudo de ventas...</p>
    </div>

    <main v-else class="kanban-board">
      <div v-for="stage in stages" :key="stage.id" class="kanban-column">
        <div class="column-header">
          <div class="column-title-row">
            <h3 class="column-title">{{ stage.name }}</h3>
            <span class="deals-count-badge">{{ stage.deals ? stage.deals.length : 0 }}</span>
          </div>
          <span class="column-value-total">Total: {{ getStageTotalValue(stage) }}</span>
        </div>

        <Draggable
          v-model="stage.deals"
          group="deals"
          item-key="id"
          class="draggable-list"
          @change="onDragChange($event, stage.id)"
        >
          <template #item="{ element }">
            <DealCard :deal="element" @delete="onDealDeleted" />
          </template>
        </Draggable>
      </div>
    </main>

    <CreateDealModal
      :show="showCreateModal"
      :stages="stages"
      @close="showCreateModal = false"
      @created="onDealCreated"
    />
  </div>
</template>

<style scoped>
.kanban-page {
  display: flex;
  flex-direction: column;
  height: 100%;
  width: 100%;
  background-color: var(--s-50, #f8fafc);
  overflow: hidden;
  box-sizing: border-box;
  font-family: system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
}

.kanban-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 1.5rem 2rem;
  background-color: var(--white, #ffffff);
  border-bottom: 1px solid var(--s-200, #e2e8f0);
}

.page-title {
  font-size: clamp(22px, 2.5vw, 30px);
  font-weight: 700;
  color: var(--s-900, #0f172a);
  margin: 0;
  font-family: inherit;
}

.page-subtitle {
  font-size: clamp(14px, 1.2vw, 16px);
  color: var(--s-500, #64748b);
  margin: 0.25rem 0 0 0;
  font-family: inherit;
}

.add-deal-btn {
  display: inline-flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.75rem 1.5rem;
  background-color: var(--b-600, #2563eb);
  color: #ffffff;
  border: none;
  border-radius: 6px;
  font-weight: 600;
  font-size: clamp(14px, 1.2vw, 16px);
  cursor: pointer;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
  transition: background-color 0.2s ease, transform 0.2s ease;
  font-family: inherit;
}

.add-deal-btn:hover {
  background-color: var(--b-700, #1d4ed8);
  transform: translateY(-1px);
}

.add-deal-btn:active {
  transform: translateY(0);
}

.btn-icon {
  font-size: 18px;
  font-weight: 700;
  line-height: 1;
}

.loader-container {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  flex: 1;
}

.spinner {
  width: 40px;
  height: 40px;
  border: 4px solid var(--s-200, #e2e8f0);
  border-top-color: var(--b-600, #2563eb);
  border-radius: 50%;
  animation: spin 1s linear infinite;
}

@keyframes spin {
  to {
    transform: rotate(360deg);
  }
}

.loader-text {
  margin-top: 1rem;
  font-size: clamp(14px, 1.2vw, 16px);
  color: var(--s-500, #64748b);
  font-family: inherit;
}

.kanban-board {
  display: flex;
  gap: 1.25rem;
  padding: 1.5rem 2rem;
  flex: 1;
  width: 100%;
  overflow-x: auto;
  align-items: stretch;
  box-sizing: border-box;
}

.kanban-column {
  display: flex;
  flex-direction: column;
  flex: 1 1 0px;
  min-width: 260px;
  max-width: 450px;
  background-color: var(--s-100, #f1f5f9);
  border: 1px solid var(--s-200, #e2e8f0);
  border-radius: 8px;
  padding: 0.75rem;
  box-sizing: border-box;
}

.column-header {
  display: flex;
  flex-direction: column;
  gap: 0.25rem;
  margin-bottom: 1rem;
  padding-bottom: 0.5rem;
  border-bottom: 2px solid var(--s-200, #cbd5e1);
}

.column-title-row {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.column-title {
  font-size: clamp(15px, 1.3vw, 17px);
  font-weight: 700;
  color: var(--s-800, #1e293b);
  margin: 0;
  font-family: inherit;
}

.deals-count-badge {
  background-color: var(--s-300, #cbd5e1);
  color: var(--s-800, #1e293b);
  font-size: 11px;
  font-weight: 700;
  padding: 0.15rem 0.5rem;
  border-radius: 9999px;
  font-family: inherit;
}

.column-value-total {
  font-size: clamp(12px, 1vw, 14px);
  font-weight: 500;
  color: var(--s-500, #64748b);
  font-family: inherit;
}

.draggable-list {
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
  flex: 1;
  overflow-y: auto;
  min-height: 200px;
  padding: 0.25rem;
}
</style>
