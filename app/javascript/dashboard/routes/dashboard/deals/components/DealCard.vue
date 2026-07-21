<script setup>
import { computed } from 'vue';
import { useAccount } from 'dashboard/composables/useAccount';
import dealApi from '../../../../api/deals';

const props = defineProps({
  deal: {
    type: Object,
    required: true,
  },
});

const emit = defineEmits(['delete']);

const { accountScopedRoute } = useAccount();

const formattedValue = computed(() => {
  const formatter = new Intl.NumberFormat('es-CO', {
    style: 'currency',
    currency: props.deal.currency || 'USD',
    minimumFractionDigits: 2,
  });
  return formatter.format(props.deal.value);
});

const contactUrl = computed(() => {
  if (!props.deal.contact) return '';
  return accountScopedRoute('contacts_edit', { contactId: props.deal.contact.id });
});

const deleteDeal = async () => {
  if (confirm('¿Estás seguro de que deseas eliminar este trato?')) {
    try {
      await dealApi.destroy(props.deal.id);
      emit('delete', props.deal.id);
    } catch (err) {
      console.error('Error deleting deal:', err);
    }
  }
};
</script>

<template>
  <div class="deal-card">
    <div class="deal-header">
      <h4 class="deal-title">{{ deal.name }}</h4>
      <button class="delete-btn" @click.stop="deleteDeal" title="Eliminar trato">
        ✕
      </button>
    </div>

    <div class="deal-body">
      <span class="deal-value">{{ formattedValue }}</span>
      <span :class="['status-badge', deal.status]">
        {{ deal.status === 'open' ? 'Abierto' : deal.status === 'won' ? 'Ganado' : 'Perdido' }}
      </span>
    </div>

    <div v-if="deal.contact" class="deal-footer">
      <router-link :to="contactUrl" class="contact-link" title="Ver perfil del cliente">
        <span class="contact-icon">👤</span>
        <span class="contact-name">{{ deal.contact.name }}</span>
      </router-link>
    </div>
  </div>
</template>

<style scoped>
.deal-card {
  background-color: var(--white, #ffffff);
  border: 1px solid var(--s-200, #e2e8f0);
  border-radius: 8px;
  padding: 1rem;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.05);
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
  cursor: grab;
  transition: transform 0.2s ease, box-shadow 0.2s ease, border-color 0.2s ease;
  user-select: none;
  box-sizing: border-box;
}

.deal-card:hover {
  transform: translateY(-2px);
  box-shadow: 0 4px 6px rgba(0, 0, 0, 0.05);
  border-color: var(--s-300, #cbd5e1);
}

.deal-card:active {
  cursor: grabbing;
}

.deal-header {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  gap: 0.5rem;
}

.deal-title {
  font-size: clamp(14px, 1.2vw, 16px);
  font-weight: 600;
  color: var(--s-800, #1e293b);
  margin: 0;
  line-height: 1.3;
}

.delete-btn {
  background: none;
  border: none;
  color: var(--s-400, #94a3b8);
  font-size: 12px;
  cursor: pointer;
  padding: 2px 6px;
  border-radius: 4px;
  transition: background-color 0.2s ease, color 0.2s ease;
}

.delete-btn:hover {
  background-color: var(--r-50, #fef2f2);
  color: var(--r-500, #ef4444);
}

.deal-body {
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 0.5rem;
}

.deal-value {
  font-size: clamp(14px, 1.2vw, 16px);
  font-weight: 700;
  color: var(--b-600, #2563eb);
}

.status-badge {
  font-size: clamp(11px, 0.9vw, 13px);
  font-weight: 600;
  padding: 0.25rem 0.5rem;
  border-radius: 4px;
  text-transform: uppercase;
}

.status-badge.open {
  background-color: var(--s-100, #f1f5f9);
  color: var(--s-700, #475569);
}

.status-badge.won {
  background-color: var(--g-100, #dcfce7);
  color: var(--g-700, #15803d);
}

.status-badge.lost {
  background-color: var(--r-100, #fee2e2);
  color: var(--r-700, #b91c1c);
}

.deal-footer {
  border-top: 1px solid var(--s-100, #f1f5f9);
  padding-top: 0.5rem;
}

.contact-link {
  display: inline-flex;
  align-items: center;
  gap: 0.35rem;
  text-decoration: none;
  color: var(--s-600, #475569);
  font-size: clamp(12px, 1vw, 14px);
  transition: color 0.2s ease;
}

.contact-link:hover {
  color: var(--b-600, #2563eb);
}

.contact-icon {
  font-size: 12px;
}

.contact-name {
  font-weight: 500;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  max-width: 150px;
}

</style>

<style>
/* Night Sky Dark Mode Palette for DealCard */
body.dark .deal-card {
  background-color: #1c1f3b !important; /* Mirage */
  border-color: #3c4068 !important; /* Fiord */
  color: #f8fafc !important;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.3);
}

body.dark .deal-card:hover {
  border-color: #4d4e80 !important; /* East Bay */
  box-shadow: 0 6px 16px rgba(0, 0, 0, 0.4);
}

body.dark .deal-title {
  color: #ffffff !important;
}

body.dark .deal-value {
  color: #60a5fa !important;
}

body.dark .status-badge.open {
  background-color: #3c4068 !important; /* Fiord */
  color: #e2e8f0 !important;
}

body.dark .deal-footer {
  border-top-color: #3c4068 !important; /* Fiord */
}

body.dark .contact-link {
  color: #a0a5c0 !important;
}

body.dark .contact-link:hover {
  color: #60a5fa !important;
}

body.dark .delete-btn {
  color: #a0a5c0 !important;
}

body.dark .delete-btn:hover {
  background-color: rgba(239, 68, 68, 0.2) !important;
  color: #f87171 !important;
}
</style>
